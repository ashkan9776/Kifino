import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

Uint8List _derivePbkdf2({
  required String password,
  required Uint8List salt,
  required int iterations,
  int keyLength = 32,
}) {
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, iterations, keyLength));
  final passwordBytes = Uint8List.fromList(utf8.encode(password));
  return derivator.process(passwordBytes);
}

(Uint8List cipherWithTag, Uint8List nonce) _encryptGcm({
  required Uint8List key,
  required Uint8List plaintext,
  Uint8List? nonce,
}) {
  final actualNonce =
      nonce ??
      () {
        final rng = Random.secure();
        return Uint8List.fromList(List.generate(12, (_) => rng.nextInt(256)));
      }();

  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      true,
      AEADParameters(KeyParameter(key), 128, actualNonce, Uint8List(0)),
    );
  final output = cipher.process(plaintext);
  return (output, actualNonce);
}

Uint8List _decryptGcm({
  required Uint8List key,
  required Uint8List nonce,
  required Uint8List cipherWithTag,
}) {
  final cipher = GCMBlockCipher(AESEngine())
    ..init(false, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
  return cipher.process(cipherWithTag);
}

void main() {
  group('PBKDF2 & AES-256-GCM verification', () {
    test('Encrypts and decrypts with GCM and PBKDF2 roundtrip', () {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final key = _derivePbkdf2(
        password: 'my-strong-password-123',
        salt: salt,
        iterations: 1000,
      );

      final plaintext = utf8.encode('{"accounts":[{"id":"1","name":"Test"}]}');
      final (cipher, nonce) = _encryptGcm(
        key: key,
        plaintext: Uint8List.fromList(plaintext),
      );

      final decrypted = _decryptGcm(
        key: key,
        nonce: nonce,
        cipherWithTag: cipher,
      );

      expect(utf8.decode(decrypted), equals(utf8.decode(plaintext)));
    });

    test('Tampering a single byte throws InvalidCipherTextException', () {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final key = _derivePbkdf2(
        password: 'my-strong-password-123',
        salt: salt,
        iterations: 1000,
      );

      final plaintext = utf8.encode('sensitive financial data');
      final (cipher, nonce) = _encryptGcm(
        key: key,
        plaintext: Uint8List.fromList(plaintext),
      );

      // Tamper one byte
      final tampered = Uint8List.fromList(cipher);
      tampered[0] ^= 0x01;

      expect(
        () => _decryptGcm(key: key, nonce: nonce, cipherWithTag: tampered),
        throwsA(isA<InvalidCipherTextException>()),
      );
    });
    test('Benchmark 300k iterations', () {
      final salt = Uint8List(16);
      final key = _derivePbkdf2(
        password: 'benchmark-password',
        salt: salt,
        iterations: 300000,
      );
      expect(key.length, equals(32));
    });
  });
}
