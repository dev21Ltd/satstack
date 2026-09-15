import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

import 'pin_crypto.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  factory SecurityService() {
    return _instance;
  }

  SecurityService._internal();

  static const String noSecurity = 'none';
  static const String pinSecurity = 'pin';

  static const String _securityTypeKey = 'security_type';
  static const String _legacyPinCodeKey = 'pin_code';
  static const String _pinHashKey = 'pin_hash';
  static const String _pinSaltKey = 'pin_salt';
  static const String _backupQuestionKey = 'backup_question';
  static const String _legacyBackupAnswerKey = 'backup_answer';
  static const String _backupAnswerHashKey = 'backup_answer_hash';
  static const String _backupAnswerSaltKey = 'backup_answer_salt';
  static const String _failedAttemptsKey = 'auth_failed_attempts';
  static const String _lockoutUntilKey = 'auth_lockout_until';
  static const String _encryptionKey = 'hive_encryption_key';
  static const String _wrappedPinKey = 'hive_key_wrapped_pin';
  static const String _wrappedRecoveryKey = 'hive_key_wrapped_recovery';
  static const String _migrationCompletedKey = 'migration_completed';
  static const String _jsonBackupPasswordKey = 'json_backup_password';
  static const String _pinKdfKey = 'pin_kdf';
  static const String _backupAnswerKdfKey = 'backup_answer_kdf';

  Uint8List? _sessionKey;

  bool get hasSessionKey => _sessionKey != null;

  Uint8List requireSessionKey() {
    final key = _sessionKey;
    if (key == null) {
      throw StateError('Portfolio storage is locked');
    }
    return Uint8List.fromList(key);
  }

  void lockSession() {
    _sessionKey = null;
  }

  Future<String> getSecurityType() async {
    return await _storage.read(key: _securityTypeKey) ?? noSecurity;
  }

  Future<void> setSecurityType(String type) async {
    if (type == noSecurity) {
      await persistUnpinnedAndClearPin();
      return;
    }
    await _storage.write(key: _securityTypeKey, value: type);
  }

  Future<void> setPinCode(String pin) async {
    if (!PinCrypto.isValidPin(pin)) {
      throw ArgumentError('PIN must be $pinMinLength–$pinMaxLength digits');
    }
    final salt = PinCrypto.generateSalt();
    final hash = PinCrypto.hashSecret(pin, salt);
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: hash);
    await _storage.write(key: _pinKdfKey, value: kdfPbkdf2Id);
    await _storage.delete(key: _legacyPinCodeKey);
    await _resetAttempts();
    final key = await _ensureSessionKey();
    await _storeWrapped(_wrappedPinKey, key, pin);
    await _storage.delete(key: _encryptionKey);
  }

  Future<void> setBackupQuestion(String question, String answer) async {
    final normalized = answer.trim().toLowerCase();
    if (question.trim().isEmpty || normalized.isEmpty) {
      throw ArgumentError('Recovery question and answer are required');
    }
    final salt = PinCrypto.generateSalt();
    final hash = PinCrypto.hashSecret(normalized, salt);
    await _storage.write(key: _backupQuestionKey, value: question.trim());
    await _storage.write(key: _backupAnswerSaltKey, value: salt);
    await _storage.write(key: _backupAnswerHashKey, value: hash);
    await _storage.write(key: _backupAnswerKdfKey, value: kdfPbkdf2Id);
    await _storage.delete(key: _legacyBackupAnswerKey);
    final key = await _ensureSessionKey();
    await _storeWrapped(_wrappedRecoveryKey, key, normalized);
    await _storage.delete(key: _encryptionKey);
  }

  Future<String?> getJsonBackupPassword() async {
    final value = await _storage.read(key: _jsonBackupPasswordKey);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<bool> hasJsonBackupPassword() async {
    return await getJsonBackupPassword() != null;
  }

  Future<void> setJsonBackupPassword(String password) async {
    if (!PinCrypto.isValidBackupPassword(password)) {
      throw ArgumentError(
        'JSON backup password must be at least $backupMinPasswordLength characters',
      );
    }
    await _storage.write(key: _jsonBackupPasswordKey, value: password);
  }

  Future<String?> getBackupQuestionText() async {
    return _storage.read(key: _backupQuestionKey);
  }

  Future<bool> hasBackupQuestion() async {
    final question = await getBackupQuestionText();
    if (question == null || question.isEmpty) return false;
    final hash = await _storage.read(key: _backupAnswerHashKey);
    final legacy = await _storage.read(key: _legacyBackupAnswerKey);
    return (hash != null && hash.isNotEmpty) ||
        (legacy != null && legacy.isNotEmpty);
  }

  Future<PinVerifyResult> verifyPin(String pin) async {
    final lockout = await _currentLockout();
    if (lockout != null) return lockout;

    final ok = await _matchesPin(pin);
    if (ok) {
      await unlockWithPin(pin);
      await _upgradeLegacyPinIfNeeded(pin);
      await _resetAttempts();
      return const PinVerifyResult.ok();
    }
    return _registerFailure('Invalid PIN');
  }

  Future<PinVerifyResult> verifyBackupAnswer(String answer) async {
    final lockout = await _currentLockout();
    if (lockout != null) return lockout;

    final ok = await _matchesBackupAnswer(answer);
    if (ok) {
      await unlockWithRecovery(answer);
      await _upgradeLegacyBackupAnswerIfNeeded(answer);
      await _resetAttempts();
      return const PinVerifyResult.ok();
    }
    return _registerFailure('Incorrect answer');
  }

  Future<void> persistUnpinnedAndClearPin() async {
    final key = await _ensureSessionKey();
    await _storage.write(key: _encryptionKey, value: base64Encode(key));
    await _storage.delete(key: _wrappedPinKey);
    await _storage.delete(key: _wrappedRecoveryKey);
    await _deletePinMaterial();
  }

  Future<void> clearSecurityData() async {
    await persistUnpinnedAndClearPin();
  }

  Future<void> wipeAll() async {
    _sessionKey = null;
    await _storage.deleteAll();
  }

  Future<void> unlockUnpinned() async {
    final type = await getSecurityType();
    if (type == pinSecurity) {
      throw StateError('PIN required to open encrypted storage');
    }
    _sessionKey = await _readOrCreatePlaintextKey();
  }

  Future<void> unlockWithPin(String pin) async {
    final wrapped = await _storage.read(key: _wrappedPinKey);
    if (wrapped != null) {
      _sessionKey = Uint8List.fromList(
        PinCrypto.unwrapBytes(pin, WrappedBytes.fromJson(jsonDecode(wrapped))),
      );
      return;
    }
    _sessionKey = await _readOrCreatePlaintextKey();
    await _storeWrapped(_wrappedPinKey, _sessionKey!, pin);
    await _storage.delete(key: _encryptionKey);
  }

  Future<void> unlockWithRecovery(String answer) async {
    final normalized = answer.trim().toLowerCase();
    final wrapped = await _storage.read(key: _wrappedRecoveryKey);
    if (wrapped != null) {
      _sessionKey = Uint8List.fromList(
        PinCrypto.unwrapBytes(
          normalized,
          WrappedBytes.fromJson(jsonDecode(wrapped)),
        ),
      );
      return;
    }
    _sessionKey = await _readOrCreatePlaintextKey();
    await _storeWrapped(_wrappedRecoveryKey, _sessionKey!, normalized);
    await _storage.delete(key: _encryptionKey);
  }

  Future<Uint8List> getEncryptionKey() async {
    if (_sessionKey != null) return Uint8List.fromList(_sessionKey!);
    final type = await getSecurityType();
    if (type == pinSecurity) {
      throw StateError('PIN required to open encrypted storage');
    }
    return _readOrCreatePlaintextKey();
  }

  Future<bool> isMigrationCompleted() async {
    return await _storage.read(key: _migrationCompletedKey) == 'true';
  }

  Future<void> setMigrationCompleted() async {
    await _storage.write(key: _migrationCompletedKey, value: 'true');
  }

  Future<Uint8List> _ensureSessionKey() async {
    if (_sessionKey != null) return Uint8List.fromList(_sessionKey!);
    _sessionKey = await _readOrCreatePlaintextKey();
    return Uint8List.fromList(_sessionKey!);
  }

  Future<Uint8List> _readOrCreatePlaintextKey() async {
    final existing = await _storage.read(key: _encryptionKey);
    if (existing != null) {
      final key = Uint8List.fromList(base64Decode(existing));
      _sessionKey = key;
      return key;
    }
    final wrappedPin = await _storage.read(key: _wrappedPinKey);
    if (wrappedPin != null) {
      throw StateError('PIN required to open encrypted storage');
    }
    final newKey = Uint8List.fromList(Hive.generateSecureKey());
    await _storage.write(key: _encryptionKey, value: base64Encode(newKey));
    _sessionKey = newKey;
    return newKey;
  }

  Future<void> _storeWrapped(String storageKey, Uint8List key, String secret) async {
    final wrapped = PinCrypto.wrapBytes(key, secret);
    await _storage.write(key: storageKey, value: jsonEncode(wrapped.toJson()));
  }

  Future<void> _deletePinMaterial() async {
    await _storage.delete(key: _securityTypeKey);
    await _storage.delete(key: _legacyPinCodeKey);
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _pinKdfKey);
    await _storage.delete(key: _backupAnswerKdfKey);
    await _storage.delete(key: _backupQuestionKey);
    await _storage.delete(key: _legacyBackupAnswerKey);
    await _storage.delete(key: _backupAnswerHashKey);
    await _storage.delete(key: _backupAnswerSaltKey);
    await _resetAttempts();
  }

  Future<bool> _matchesPin(String pin) async {
    final hash = await _storage.read(key: _pinHashKey);
    final salt = await _storage.read(key: _pinSaltKey);
    if (hash != null && salt != null) {
      final kdf = await _storage.read(key: _pinKdfKey);
      final computed = PinCrypto.hashSecretWithKdf(pin, salt, kdf);
      return PinCrypto.constantTimeEquals(computed, hash);
    }
    final legacy = await _storage.read(key: _legacyPinCodeKey);
    if (legacy == null) return false;
    if (PinCrypto.isLegacySecret(legacy)) {
      return pin == legacy;
    }
    return false;
  }

  Future<void> _upgradeLegacyPinIfNeeded(String pin) async {
    final hash = await _storage.read(key: _pinHashKey);
    final kdf = await _storage.read(key: _pinKdfKey);
    final wrapped = await _storage.read(key: _wrappedPinKey);
    final needsHash = hash == null || kdf != kdfPbkdf2Id;
    final needsWrap = wrapped == null || !wrapped.contains(algAesGcm);
    if (!needsHash && !needsWrap) return;
    final legacy = await _storage.read(key: _legacyPinCodeKey);
    if (hash == null &&
        (legacy == null || !PinCrypto.isLegacySecret(legacy) || pin != legacy)) {
      return;
    }
    await setPinCode(pin);
  }

  Future<bool> _matchesBackupAnswer(String answer) async {
    final normalized = answer.trim().toLowerCase();
    final hash = await _storage.read(key: _backupAnswerHashKey);
    final salt = await _storage.read(key: _backupAnswerSaltKey);
    if (hash != null && salt != null) {
      final kdf = await _storage.read(key: _backupAnswerKdfKey);
      final computed = PinCrypto.hashSecretWithKdf(normalized, salt, kdf);
      return PinCrypto.constantTimeEquals(computed, hash);
    }
    final legacy = await _storage.read(key: _legacyBackupAnswerKey);
    if (legacy == null) return false;
    return normalized == legacy.toLowerCase();
  }

  Future<void> _upgradeLegacyBackupAnswerIfNeeded(String answer) async {
    final question = await _storage.read(key: _backupQuestionKey);
    if (question == null || question.isEmpty) return;
    final hash = await _storage.read(key: _backupAnswerHashKey);
    final kdf = await _storage.read(key: _backupAnswerKdfKey);
    final wrapped = await _storage.read(key: _wrappedRecoveryKey);
    final needsHash = hash == null || kdf != kdfPbkdf2Id;
    final needsWrap = wrapped == null || !wrapped.contains(algAesGcm);
    if (!needsHash && !needsWrap) return;
    final legacy = await _storage.read(key: _legacyBackupAnswerKey);
    if (hash == null &&
        (legacy == null ||
            answer.trim().toLowerCase() != legacy.toLowerCase())) {
      return;
    }
    await setBackupQuestion(question, answer);
  }

  Future<PinVerifyResult?> _currentLockout() async {
    final untilRaw = await _storage.read(key: _lockoutUntilKey);
    if (untilRaw == null) return null;
    final until = DateTime.tryParse(untilRaw);
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      await _storage.delete(key: _lockoutUntilKey);
      return null;
    }
    return PinVerifyResult.failed(
      lockedOut: true,
      retryAfter: remaining,
      remainingAttempts: 0,
      message:
          'Too many attempts. Try again in ${PinCrypto.formatRetryAfter(remaining)}.',
    );
  }

  Future<PinVerifyResult> _registerFailure(String invalidMessage) async {
    final current = int.tryParse(
          await _storage.read(key: _failedAttemptsKey) ?? '0',
        ) ??
        0;
    final failed = current + 1;
    await _storage.write(key: _failedAttemptsKey, value: failed.toString());

    final delay = PinCrypto.lockoutDuration(failed);
    if (delay > Duration.zero) {
      await _storage.write(
        key: _lockoutUntilKey,
        value: DateTime.now().add(delay).toIso8601String(),
      );
      return PinVerifyResult.failed(
        lockedOut: true,
        retryAfter: delay,
        remainingAttempts: 0,
        message:
            'Too many attempts. Try again in ${PinCrypto.formatRetryAfter(delay)}.',
      );
    }

    final remaining = PinCrypto.remainingAttempts(failed);
    return PinVerifyResult.failed(
      remainingAttempts: remaining,
      message: remaining == 1
          ? '$invalidMessage. 1 attempt left.'
          : '$invalidMessage. $remaining attempts left.',
    );
  }

  Future<void> _resetAttempts() async {
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockoutUntilKey);
  }
}
