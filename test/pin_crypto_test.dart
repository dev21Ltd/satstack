import 'package:flutter_test/flutter_test.dart';
import 'package:satstack/pin_crypto.dart';

void main() {
  test('valid PIN is 4–6 digits', () {
    expect(PinCrypto.isValidPin('1234'), isTrue);
    expect(PinCrypto.isValidPin('123456'), isTrue);
    expect(PinCrypto.isValidPin('123'), isFalse);
    expect(PinCrypto.isValidPin('1234567'), isFalse);
    expect(PinCrypto.isValidPin('12ab'), isFalse);
  });

  test('hash is deterministic for the same salt and secret', () {
    const salt = 'abc123';
    final first = PinCrypto.hashSecret('1234', salt, iterations: 32);
    final second = PinCrypto.hashSecret('1234', salt, iterations: 32);
    expect(first, second);
    expect(first.length, 64);
  });

  test('different salts produce different hashes', () {
    final a = PinCrypto.hashSecret('1234', 'salt-a', iterations: 32);
    final b = PinCrypto.hashSecret('1234', 'salt-b', iterations: 32);
    expect(a, isNot(b));
  });

  test('legacy PIN detection does not treat hashes as PINs', () {
    expect(PinCrypto.isLegacySecret('1234'), isTrue);
    expect(PinCrypto.isLegacySecret(PinCrypto.hashSecret('1234', 's', iterations: 8)), isFalse);
    expect(PinCrypto.looksLikeHash(PinCrypto.hashSecret('1234', 's', iterations: 8)), isTrue);
  });

  test('constant-time equals rejects mismatches', () {
    expect(PinCrypto.constantTimeEquals('abcd', 'abcd'), isTrue);
    expect(PinCrypto.constantTimeEquals('abcd', 'abce'), isFalse);
    expect(PinCrypto.constantTimeEquals('abc', 'abcd'), isFalse);
  });

  test('lockout grows after every 5 failures', () {
    expect(PinCrypto.lockoutDuration(4), Duration.zero);
    expect(PinCrypto.lockoutDuration(5), const Duration(seconds: 30));
    expect(PinCrypto.lockoutDuration(10), const Duration(seconds: 60));
    expect(PinCrypto.lockoutDuration(15), const Duration(seconds: 300));
  });

  test('remaining attempts wrap per lockout window', () {
    expect(PinCrypto.remainingAttempts(0), 5);
    expect(PinCrypto.remainingAttempts(1), 4);
    expect(PinCrypto.remainingAttempts(4), 1);
    expect(PinCrypto.remainingAttempts(6), 4);
  });

  test('wrapBytes AES-GCM round-trips and rejects a wrong password', () {
    final secret = List<int>.generate(32, (i) => i);
    final wrapped = PinCrypto.wrapBytes(secret, 'correct-password', iterations: 32);
    expect(wrapped.alg, algAesGcm);
    expect(PinCrypto.unwrapBytes('correct-password', wrapped), secret);
    expect(
      () => PinCrypto.unwrapBytes('wrong-password', wrapped),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('legacy HMAC wrap still decrypts', () {
    final secret = List<int>.generate(32, (i) => i);
    final wrapped = PinCrypto.wrapLegacyHmacStreamForTest(
      secret,
      'legacy-pass',
      iterations: 32,
    );
    expect(wrapped.alg, algHmacStream);
    expect(PinCrypto.unwrapBytes('legacy-pass', wrapped), secret);
  });

  test('encrypted backup envelope round-trips with AES-GCM', () {
    const payload = '{"version":3,"purchases":[]}';
    final envelope = PinCrypto.encryptBackup(payload, 'backup-secret', iterations: 32);
    expect(PinCrypto.isEncryptedBackup(envelope), isTrue);
    expect(envelope['version'], 5);
    expect(PinCrypto.decryptBackup(envelope, 'backup-secret'), payload);
  });
}
