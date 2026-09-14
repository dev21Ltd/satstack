import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

const int pinHashIterations = 12000;
const int pinMinLength = 4;
const int pinMaxLength = 6;
const int maxAttemptsBeforeLockout = 5;
const int backupMinPasswordLength = 8;
const String encryptedBackupFormat = 'satstack-encrypted';

class PinVerifyResult {
  final bool success;
  final bool lockedOut;
  final Duration retryAfter;
  final int remainingAttempts;
  final String message;

  const PinVerifyResult.ok()
      : success = true,
        lockedOut = false,
        retryAfter = Duration.zero,
        remainingAttempts = maxAttemptsBeforeLockout,
        message = '';

  const PinVerifyResult.failed({
    required this.message,
    this.remainingAttempts = 0,
    this.lockedOut = false,
    this.retryAfter = Duration.zero,
  }) : success = false;
}

class PinCrypto {
  static final _legacySecret = RegExp(r'^\d{4,6}$');
  static final _hashFormat = RegExp(r'^[a-f0-9]{64}$');

  static bool isLegacySecret(String stored) => _legacySecret.hasMatch(stored);

  static bool looksLikeHash(String stored) => _hashFormat.hasMatch(stored);

  static String generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Encode(bytes);
  }

  static String hashSecret(
    String secret,
    String salt, {
    int iterations = pinHashIterations,
  }) {
    var digest = sha256.convert(utf8.encode('$salt\u0000$secret'));
    for (var i = 1; i < iterations; i++) {
      digest = sha256.convert(digest.bytes);
    }
    return digest.toString();
  }

  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  static bool isValidPin(String pin) {
    return pin.length >= pinMinLength &&
        pin.length <= pinMaxLength &&
        RegExp(r'^\d+$').hasMatch(pin);
  }

  static Duration lockoutDuration(int failedAttempts) {
    if (failedAttempts < maxAttemptsBeforeLockout) return Duration.zero;
    final lockoutIndex = (failedAttempts ~/ maxAttemptsBeforeLockout) - 1;
    const seconds = [30, 60, 300, 900, 3600];
    final index = lockoutIndex.clamp(0, seconds.length - 1);
    return Duration(seconds: seconds[index]);
  }

  static int remainingAttempts(int failedAttempts) {
    if (failedAttempts <= 0) return maxAttemptsBeforeLockout;
    final usedInWindow = failedAttempts % maxAttemptsBeforeLockout;
    if (usedInWindow == 0) return maxAttemptsBeforeLockout;
    return maxAttemptsBeforeLockout - usedInWindow;
  }

  static String formatRetryAfter(Duration duration) {
    final seconds = duration.inSeconds.clamp(1, 3600);
    if (seconds < 60) return '${seconds}s';
    final minutes = (seconds / 60).ceil();
    return '${minutes}m';
  }

  static bool isValidBackupPassword(String password) {
    return password.length >= backupMinPasswordLength;
  }

  static List<int> deriveKeyBytes(
    String secret,
    String salt, {
    int iterations = pinHashIterations,
  }) {
    final hex = hashSecret(secret, salt, iterations: iterations);
    final out = <int>[];
    for (var i = 0; i + 1 < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  static List<int> _hmac(List<int> key, List<int> message) {
    return Hmac(sha256, key).convert(message).bytes;
  }

  static bool constantTimeBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  static List<int> _keystream(List<int> kek, List<int> iv, int length) {
    final out = <int>[];
    var counter = 0;
    while (out.length < length) {
      out.addAll(_hmac(kek, [
        ...iv,
        (counter >> 24) & 0xff,
        (counter >> 16) & 0xff,
        (counter >> 8) & 0xff,
        counter & 0xff,
      ]));
      counter++;
    }
    return out.sublist(0, length);
  }

  static WrappedBytes wrapBytes(List<int> data, String password) {
    final salt = generateSalt();
    final iv = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final kek = deriveKeyBytes(password, salt);
    final ks = _keystream(kek, iv, data.length);
    final ct = List<int>.generate(data.length, (i) => data[i] ^ ks[i]);
    final mac = _hmac(kek, [...iv, ...ct]);
    return WrappedBytes(
      salt: salt,
      iv: base64Encode(iv),
      ciphertext: base64Encode(ct),
      mac: base64Encode(mac),
    );
  }

  static List<int> unwrapBytes(String password, WrappedBytes wrapped) {
    final kek = deriveKeyBytes(password, wrapped.salt);
    final iv = base64Decode(wrapped.iv);
    final ct = base64Decode(wrapped.ciphertext);
    final mac = base64Decode(wrapped.mac);
    final expected = _hmac(kek, [...iv, ...ct]);
    if (!constantTimeBytes(mac, expected)) {
      throw ArgumentError('Invalid password or corrupt data');
    }
    final ks = _keystream(kek, iv, ct.length);
    return List<int>.generate(ct.length, (i) => ct[i] ^ ks[i]);
  }

  static Map<String, dynamic> encryptBackup(String plaintext, String password) {
    final wrapped = wrapBytes(utf8.encode(plaintext), password);
    return {
      'format': encryptedBackupFormat,
      'version': 4,
      'kdf': 'sha256-iter-$pinHashIterations',
      ...wrapped.toJson(),
    };
  }

  static String decryptBackup(Map<String, dynamic> envelope, String password) {
    final wrapped = WrappedBytes.fromJson(envelope);
    return utf8.decode(unwrapBytes(password, wrapped));
  }

  static bool isEncryptedBackup(dynamic json) {
    return json is Map && json['format'] == encryptedBackupFormat;
  }
}

class WrappedBytes {
  final String salt;
  final String iv;
  final String ciphertext;
  final String mac;

  const WrappedBytes({
    required this.salt,
    required this.iv,
    required this.ciphertext,
    required this.mac,
  });

  Map<String, String> toJson() => {
        'salt': salt,
        'iv': iv,
        'ciphertext': ciphertext,
        'mac': mac,
      };

  factory WrappedBytes.fromJson(Map<String, dynamic> json) {
    return WrappedBytes(
      salt: json['salt'] as String,
      iv: json['iv'] as String,
      ciphertext: json['ciphertext'] as String,
      mac: json['mac'] as String,
    );
  }
}
