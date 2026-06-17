import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pointycastle/digests/sha256.dart';

/// Service for managing app-level PIN and biometric authentication.
/// PIN is stored as a salted SHA-256 hash via FlutterSecureStorage.
class AppLockService {
  static const _kPinHash = 'app_lock_pin_hash'; // salt:hash
  static const _kBiometricEnabled = 'app_lock_biometric';

  final FlutterSecureStorage? _storage;
  final LocalAuthentication? _localAuth;
  final SHA256Digest _digest;

  AppLockService({FlutterSecureStorage? storage, LocalAuthentication? localAuth})
      : _storage = storage,
        _localAuth = localAuth,
        _digest = SHA256Digest();

  FlutterSecureStorage get _store => _storage ?? const FlutterSecureStorage();
  LocalAuthentication get _auth => _localAuth ?? LocalAuthentication();

  // ── PIN ──

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _store.write(key: _kPinHash, value: '$salt:$hash');
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _store.read(key: _kPinHash);
    if (stored == null) return false;
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    final hash = _hashPin(pin, parts[0]);
    return hash == parts[1];
  }

  Future<bool> hasPin() async =>
      (await _store.read(key: _kPinHash)) != null;

  Future<void> clearPin() async {
    await _store.delete(key: _kPinHash);
    await _store.delete(key: _kBiometricEnabled);
  }

  // ── Biometric ──

  Future<bool> isBiometricAvailable() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> getBiometricEnabled() async =>
      (await _store.read(key: _kBiometricEnabled)) == 'true';

  Future<void> setBiometricEnabled(bool enabled) async {
    await _store.write(key: _kBiometricEnabled, value: enabled ? 'true' : 'false');
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Feya PDF',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  // ── Hashing helpers ──

  String _generateSalt() {
    final rng = Random.secure();
    final bytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return base64.encode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final input = utf8.encode('$salt:$pin');
    final hash = _digest.process(input);
    return base64.encode(hash);
  }
}
