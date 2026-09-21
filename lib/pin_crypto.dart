import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart' as pc;

const int pinHashIterations = 12000;
/// PIN wrap must stay snappy on a phone. JSON files can afford more stretch.
const int pbkdf2Iterations = 12000;
const int backupPbkdf2Iterations = 100000;
const int _slowKdfIsolateThreshold = 25000;
const int pinMinLength = 4;
const int pinMaxLength = 6;
const int maxAttemptsBeforeLockout = 5;
const int backupMinPasswordLength = 8;
const String encryptedBackupFormat = 'satstack-encrypted';
const String kdfPbkdf2Id = 'pbkdf2-sha256-12000';
const String kdfLegacySha256Id = 'sha256-iter-12000';
const String algAesGcm = 'aes-256-gcm';
const String algHmacStream = 'hmac-sha256-stream';

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

  static String hashSecretLegacySha256(
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

  static String hashSecret(
    String secret,
    String salt, {
    int iterations = pbkdf2Iterations,
  }) {
    final dk = pbkdf2HmacSha256(
      password: utf8.encode(secret),
      salt: utf8.encode(salt),
      iterations: iterations,
    );
    return dk.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static int iterationsFromKdf(String? kdf) {
    if (kdf == null || kdf.startsWith('sha256-iter')) {
      return pinHashIterations;
    }
    final match = RegExp(r'pbkdf2-sha256-(\d+)').firstMatch(kdf);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? pbkdf2Iterations;
    }
    return pbkdf2Iterations;
  }

  static String hashSecretWithKdf(String secret, String salt, String? kdf) {
    if (kdf == null || kdf.startsWith('sha256-iter')) {
      return hashSecretLegacySha256(secret, salt);
    }
    return hashSecret(secret, salt, iterations: iterationsFromKdf(kdf));
  }

  static List<int> pbkdf2HmacSha256({
    required List<int> password,
    required List<int> salt,
    int iterations = pbkdf2Iterations,
    int length = 32,
  }) {
    if (iterations < 1 || length < 1) {
      throw ArgumentError('Invalid PBKDF2 parameters');
    }
    final hmac = Hmac(sha256, password);
    final blockCount = (length + 31) ~/ 32;
    final out = <int>[];
    for (var blockIndex = 1; blockIndex <= blockCount; blockIndex++) {
      final block = Uint8List(salt.length + 4);
      block.setAll(0, salt);
      block[salt.length] = (blockIndex >> 24) & 0xff;
      block[salt.length + 1] = (blockIndex >> 16) & 0xff;
      block[salt.length + 2] = (blockIndex >> 8) & 0xff;
      block[salt.length + 3] = blockIndex & 0xff;
      var u = hmac.convert(block).bytes;
      final t = List<int>.from(u);
      for (var j = 1; j < iterations; j++) {
        u = hmac.convert(u).bytes;
        for (var k = 0; k < t.length; k++) {
          t[k] ^= u[k];
        }
      }
      out.addAll(t);
    }
    return out.sublist(0, length);
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
    int iterations = pbkdf2Iterations,
    String kdf = kdfPbkdf2Id,
  }) {
    if (kdf.startsWith('sha256-iter')) {
      final hex = hashSecretLegacySha256(secret, salt, iterations: iterations);
      final out = <int>[];
      for (var i = 0; i + 1 < hex.length; i += 2) {
        out.add(int.parse(hex.substring(i, i + 2), radix: 16));
      }
      return out;
    }
    return pbkdf2HmacSha256(
      password: utf8.encode(secret),
      salt: base64Decode(salt),
      iterations: iterations,
    );
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

  static List<int> _aesGcmProcess({
    required bool encrypt,
    required List<int> key,
    required List<int> nonce,
    required List<int> data,
  }) {
    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(
        encrypt,
        pc.AEADParameters(
          pc.KeyParameter(Uint8List.fromList(key)),
          128,
          Uint8List.fromList(nonce),
          Uint8List(0),
        ),
      );
    return cipher.process(Uint8List.fromList(data));
  }

  static WrappedBytes wrapBytes(
    List<int> data,
    String password, {
    int iterations = pbkdf2Iterations,
  }) {
    final salt = generateSalt();
    final nonce = List<int>.generate(12, (_) => Random.secure().nextInt(256));
    final kek = deriveKeyBytes(password, salt, iterations: iterations);
    final packed = _aesGcmProcess(
      encrypt: true,
      key: kek,
      nonce: nonce,
      data: data,
    );
    return WrappedBytes(
      salt: salt,
      nonce: base64Encode(nonce),
      ciphertext: base64Encode(packed),
      kdf: kdfPbkdf2Id,
      alg: algAesGcm,
      iterations: iterations,
    );
  }

  static List<int> unwrapBytes(
    String password,
    WrappedBytes wrapped, {
    int? iterations,
  }) {
    if (wrapped.isAesGcm) {
      final kek = deriveKeyBytes(
        password,
        wrapped.salt,
        iterations: iterations ?? wrapped.iterations,
        kdf: wrapped.kdf,
      );
      try {
        return _aesGcmProcess(
          encrypt: false,
          key: kek,
          nonce: base64Decode(wrapped.nonce!),
          data: base64Decode(wrapped.ciphertext),
        );
      } catch (_) {
        throw ArgumentError('Invalid password or corrupt data');
      }
    }
    return _unwrapLegacyHmacStream(password, wrapped, iterations: iterations);
  }

  static List<int> _unwrapLegacyHmacStream(
    String password,
    WrappedBytes wrapped, {
    int? iterations,
  }) {
    final kek = deriveKeyBytes(
      password,
      wrapped.salt,
      iterations: iterations ?? wrapped.iterations,
      kdf: wrapped.kdf.isEmpty ? kdfLegacySha256Id : wrapped.kdf,
    );
    final iv = base64Decode(wrapped.iv ?? '');
    final ct = base64Decode(wrapped.ciphertext);
    final mac = base64Decode(wrapped.mac ?? '');
    final expected = _hmac(kek, [...iv, ...ct]);
    if (!constantTimeBytes(mac, expected)) {
      throw ArgumentError('Invalid password or corrupt data');
    }
    final ks = _keystream(kek, iv, ct.length);
    return List<int>.generate(ct.length, (i) => ct[i] ^ ks[i]);
  }

  static WrappedBytes wrapLegacyHmacStreamForTest(
    List<int> data,
    String password, {
    int iterations = pinHashIterations,
  }) {
    final salt = generateSalt();
    final iv = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final kek = deriveKeyBytes(
      password,
      salt,
      iterations: iterations,
      kdf: kdfLegacySha256Id,
    );
    final ks = _keystream(kek, iv, data.length);
    final ct = List<int>.generate(data.length, (i) => data[i] ^ ks[i]);
    final mac = _hmac(kek, [...iv, ...ct]);
    return WrappedBytes(
      salt: salt,
      iv: base64Encode(iv),
      ciphertext: base64Encode(ct),
      mac: base64Encode(mac),
      kdf: kdfLegacySha256Id,
      alg: algHmacStream,
      iterations: iterations,
    );
  }

  static Map<String, dynamic> encryptBackup(
    String plaintext,
    String password, {
    int iterations = backupPbkdf2Iterations,
  }) {
    final wrapped = wrapBytes(
      utf8.encode(plaintext),
      password,
      iterations: iterations,
    );
    return {
      'format': encryptedBackupFormat,
      'version': 5,
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

  static Future<WrappedBytes> wrapBytesAsync(List<int> data, String password) async {
    if (pbkdf2Iterations <= _slowKdfIsolateThreshold) {
      return wrapBytes(data, password);
    }
    final json = await compute(_wrapBytesIsolate, <String, dynamic>{
      'data': List<int>.from(data),
      'password': password,
    });
    return WrappedBytes.fromJson(Map<String, dynamic>.from(json as Map));
  }

  static Future<List<int>> unwrapBytesAsync(String password, WrappedBytes wrapped) async {
    if (wrapped.iterations <= _slowKdfIsolateThreshold) {
      return unwrapBytes(password, wrapped);
    }
    return compute(_unwrapBytesIsolate, <String, dynamic>{
      'password': password,
      'wrapped': wrapped.toJson(),
    });
  }

  static Future<String> hashSecretWithKdfAsync(
    String secret,
    String salt,
    String? kdf,
  ) async {
    if (iterationsFromKdf(kdf) <= _slowKdfIsolateThreshold) {
      return hashSecretWithKdf(secret, salt, kdf);
    }
    return compute(_hashSecretIsolate, <String, dynamic>{
      'secret': secret,
      'salt': salt,
      'kdf': kdf,
    });
  }
}

Map<String, dynamic> _wrapBytesIsolate(Map<String, dynamic> message) {
  final wrapped = PinCrypto.wrapBytes(
    List<int>.from(message['data'] as List),
    message['password'] as String,
  );
  return wrapped.toJson();
}

List<int> _unwrapBytesIsolate(Map<String, dynamic> message) {
  return PinCrypto.unwrapBytes(
    message['password'] as String,
    WrappedBytes.fromJson(Map<String, dynamic>.from(message['wrapped'] as Map)),
  );
}

String _hashSecretIsolate(Map<String, dynamic> message) {
  return PinCrypto.hashSecretWithKdf(
    message['secret'] as String,
    message['salt'] as String,
    message['kdf'] as String?,
  );
}

class WrappedBytes {
  final String salt;
  final String? iv;
  final String? nonce;
  final String ciphertext;
  final String? mac;
  final String kdf;
  final String alg;
  final int iterations;

  const WrappedBytes({
    required this.salt,
    required this.ciphertext,
    this.iv,
    this.nonce,
    this.mac,
    this.kdf = kdfPbkdf2Id,
    this.alg = algAesGcm,
    this.iterations = pbkdf2Iterations,
  });

  bool get isAesGcm => alg == algAesGcm && nonce != null;

  Map<String, dynamic> toJson() => {
        'salt': salt,
        'ciphertext': ciphertext,
        'kdf': kdf,
        'alg': alg,
        'iterations': iterations,
        if (nonce != null) 'nonce': nonce!,
        if (iv != null) 'iv': iv!,
        if (mac != null) 'mac': mac!,
      };

  factory WrappedBytes.fromJson(Map<String, dynamic> json) {
    final alg = (json['alg'] as String?) ??
        (json['nonce'] != null ? algAesGcm : algHmacStream);
    final kdf = (json['kdf'] as String?) ??
        (alg == algAesGcm ? kdfPbkdf2Id : kdfLegacySha256Id);
    final iterations = (json['iterations'] as num?)?.toInt() ??
        (alg == algAesGcm ? pbkdf2Iterations : pinHashIterations);
    return WrappedBytes(
      salt: json['salt'] as String,
      ciphertext: json['ciphertext'] as String,
      iv: json['iv'] as String?,
      nonce: json['nonce'] as String?,
      mac: json['mac'] as String?,
      kdf: kdf,
      alg: alg,
      iterations: iterations,
    );
  }
}
