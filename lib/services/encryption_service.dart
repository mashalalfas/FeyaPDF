import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/export.dart';

/// Encrypts and decrypts PDF bytes using AES-256-GCM.
///
/// Format:
///   "MELY" + version(1) + iv(12) + salt(32) + ciphertext + auth_tag(16)
///
/// Key derivation: PBKDF2-SHA256, 600,000 iterations, 32-byte key.
///
/// Same format as Melody MD's encryption, just applied to PDF bytes.
class EncryptionService {
  static const _magic = [0x4D, 0x45, 0x4C, 0x59]; // "MELY"
  static const _version = 1;
  static const _saltLength = 32;
  static const _ivLength = 12;
  static const _iterations = 600000; // OWASP recommendation

  /// Encrypt raw bytes (e.g. a PDF) with the given passphrase.
  /// Returns raw bytes (magic + header + ciphertext).
  static Uint8List encryptBytes(Uint8List plaintext, String passphrase) {
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List.generate(_saltLength, (_) => random.nextInt(256)),
    );
    final iv = IV.fromSecureRandom(_ivLength);

    final key = _deriveKey(passphrase, salt);
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    final encrypted = encrypter.encryptBytes(plaintext, iv: iv);

    // Build output buffer
    final builder = BytesBuilder();
    builder.add(_magic);
    builder.addByte(_version);
    builder.add(iv.bytes);
    builder.add(salt);
    builder.add(encrypted.bytes);

    return builder.toBytes();
  }

  /// Decrypt bytes back to plaintext.
  /// Throws [EncryptionException] if passphrase is wrong or data is corrupt.
  static Uint8List decryptBytes(Uint8List data, String passphrase) {
    if (data.length < _minLength) {
      throw const EncryptionException('File too small to be encrypted');
    }

    // Verify magic
    if (data[0] != _magic[0] ||
        data[1] != _magic[1] ||
        data[2] != _magic[2] ||
        data[3] != _magic[3]) {
      throw const EncryptionException('Invalid file format');
    }

    final version = data[4];
    if (version > _version) {
      throw EncryptionException('Unsupported version: $version');
    }

    final iv = IV(data.sublist(5, 5 + _ivLength));
    final salt = data.sublist(5 + _ivLength, 5 + _ivLength + _saltLength);
    final ciphertext = data.sublist(5 + _ivLength + _saltLength);

    final key = _deriveKey(passphrase, Uint8List.fromList(salt));
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));

    try {
      final encrypted = Encrypted(ciphertext);
      return Uint8List.fromList(encrypter.decryptBytes(encrypted, iv: iv));
    } catch (e) {
      throw const EncryptionException('Wrong passphrase or corrupted file');
    }
  }

  /// Derive a 32-byte key from passphrase + salt using PBKDF2.
  static Key _deriveKey(String passphrase, Uint8List salt) {
    final params = Pbkdf2Parameters(salt, _iterations, 32);
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(params);
    final keyBytes = pbkdf2.process(
      Uint8List.fromList(utf8.encode(passphrase)),
    );
    return Key(keyBytes);
  }

  static const _minLength = 5 + _ivLength + _saltLength + 1; // minimal valid file
}

class EncryptionException implements Exception {
  final String message;
  const EncryptionException(this.message);

  @override
  String toString() => 'EncryptionException: $message';
}
