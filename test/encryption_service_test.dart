import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody_pdf/services/encryption_service.dart';


void main() {
  group('EncryptionService', () {
    const passphrase = 'test-passphrase-123';

    test('encrypt then decrypt returns same bytes', () {
      final original = Uint8List.fromList('Hello Melody PDF!'.codeUnits);
      final encrypted = EncryptionService.encryptBytes(original, passphrase);
      final decrypted = EncryptionService.decryptBytes(encrypted, passphrase);
      expect(decrypted, equals(original));
    });

    test('wrong passphrase throws EncryptionException', () {
      final encrypted = EncryptionService.encryptBytes(
        Uint8List.fromList('secret data'.codeUnits),
        passphrase,
      );
      expect(
        () => EncryptionService.decryptBytes(encrypted, 'wrong-passphrase'),
        throwsA(isA<EncryptionException>()),
      );
    });

    test('corrupted data throws EncryptionException', () {
      // Build a "valid looking" blob by encrypting then tampering with bytes in the middle
      final encrypted = EncryptionService.encryptBytes(
        Uint8List.fromList('corruption test'.codeUnits),
        passphrase,
      );
      final corrupted = Uint8List.fromList(encrypted);
      corrupted[20] ^= 0xFF; // flip bits deep in the ciphertext
      expect(
        () => EncryptionService.decryptBytes(corrupted, passphrase),
        throwsA(isA<EncryptionException>()),
      );
    });

    test('truncated data throws EncryptionException', () {
      final encrypted = EncryptionService.encryptBytes(
        Uint8List.fromList('data'.codeUnits),
        passphrase,
      );
      final truncated = encrypted.sublist(0, 10); // way too short
      expect(
        () => EncryptionService.decryptBytes(truncated, passphrase),
        throwsA(isA<EncryptionException>()),
      );
    });

    test('empty bytes round-trips correctly', () {
      final original = Uint8List(0);
      final encrypted = EncryptionService.encryptBytes(original, passphrase);
      final decrypted = EncryptionService.decryptBytes(encrypted, passphrase);
      expect(decrypted.length, equals(0));
    });

    test('large payload (1MB random data) round-trips correctly', () {
      final random = Random(42);
      final original = Uint8List.fromList(
        List.generate(1 * 1024 * 1024, (_) => random.nextInt(256)),
      );
      final encrypted = EncryptionService.encryptBytes(original, passphrase);
      final decrypted = EncryptionService.decryptBytes(encrypted, passphrase);
      expect(decrypted, equals(original));
    });

    test('different passphrases produce different ciphertexts', () {
      final original = Uint8List.fromList('same plaintext'.codeUnits);
      final enc1 = EncryptionService.encryptBytes(original, 'pass-a');
      final enc2 = EncryptionService.encryptBytes(original, 'pass-b');
      // Ciphertexts differ (random salt/IV per call)
      expect(enc1, isNot(equals(enc2)));
    });

    test('encrypted output has magic header MELY', () {
      final encrypted = EncryptionService.encryptBytes(
        Uint8List.fromList('header check'.codeUnits),
        passphrase,
      );
      expect(encrypted[0], equals(0x4D));
      expect(encrypted[1], equals(0x45));
      expect(encrypted[2], equals(0x4C));
      expect(encrypted[3], equals(0x59));
    });

    test('binary data (non-UTF8 bytes) round-trips correctly', () {
      // Bytes that are not valid UTF-8 — proves we're handling raw bytes, not strings
      final original = Uint8List.fromList(List.generate(256, (i) => i));
      final encrypted = EncryptionService.encryptBytes(original, passphrase);
      final decrypted = EncryptionService.decryptBytes(encrypted, passphrase);
      expect(decrypted, equals(original));
    });
  });
}
