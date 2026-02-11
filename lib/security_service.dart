import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'dart:convert';
import 'dart:typed_data';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  factory SecurityService() {
    return _instance;
  }

  SecurityService._internal();

  // Security types
  static const String noSecurity = 'none';
  static const String pinSecurity = 'pin';

  // Keys for secure storage
  static const String _securityTypeKey = 'security_type';
  static const String _pinCodeKey = 'pin_code';
  static const String _backupQuestionKey = 'backup_question';
  static const String _backupAnswerKey = 'backup_answer';
  static const String _encryptionKey = 'hive_encryption_key';
  static const String _migrationCompletedKey = 'migration_completed';

  Future<String> getSecurityType() async {
    return await _storage.read(key: _securityTypeKey) ?? noSecurity;
  }

  Future<void> setSecurityType(String type) async {
    await _storage.write(key: _securityTypeKey, value: type);
  }

  Future<void> setPinCode(String pin) async {
    await _storage.write(key: _pinCodeKey, value: pin);
  }

  Future<String?> getPinCode() async {
    return await _storage.read(key: _pinCodeKey);
  }

  Future<void> setBackupQuestion(String question, String answer) async {
    await _storage.write(key: _backupQuestionKey, value: question);
    await _storage.write(key: _backupAnswerKey, value: answer.toLowerCase());
  }

  Future<Map<String, String>?> getBackupQuestion() async {
    final question = await _storage.read(key: _backupQuestionKey);
    final answer = await _storage.read(key: _backupAnswerKey);

    if (question != null && answer != null) {
      return {'question': question, 'answer': answer};
    }
    return null;
  }

  Future<bool> checkBackupAnswer(String answer) async {
    final storedAnswer = await _storage.read(key: _backupAnswerKey);
    return storedAnswer == answer.toLowerCase();
  }

  Future<void> clearSecurityData() async {
    await _storage.delete(key: _securityTypeKey);
    await _storage.delete(key: _pinCodeKey);
    await _storage.delete(key: _backupQuestionKey);
    await _storage.delete(key: _backupAnswerKey);
  }

  // Encryption key methods
  Future<Uint8List> getEncryptionKey() async {
    String? key = await _storage.read(key: _encryptionKey);
    if (key == null) {
      final newKey = Hive.generateSecureKey();
      await _storage.write(
        key: _encryptionKey,
        value: base64Encode(newKey),
      );
      return Uint8List.fromList(newKey);
    }
    return base64Decode(key);
  }

  // Migration status
  Future<bool> isMigrationCompleted() async {
    return await _storage.read(key: _migrationCompletedKey) == 'true';
  }

  Future<void> setMigrationCompleted() async {
    await _storage.write(key: _migrationCompletedKey, value: 'true');
  }
}