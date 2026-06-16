import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

/// Thin wrapper over SharedPreferences.
/// EncryptionProvider is single source of truth for passphrase —
/// passphrase is completely removed from this service.
class SettingsService {
  static const _prefix = 'mely_pdf_';

  // --- Keys ---
  static const _kThemeMode = '${_prefix}theme_mode'; // 'light'|'dark'|'system'
  static const _kAutoEncrypt = '${_prefix}auto_encrypt'; // bool
  static const _kUserProfile = '${_prefix}user_profile'; // JSON string
  static const _kLastDir = '${_prefix}last_dir'; // string (migrated from old key)
  static const _kLastReadPositions = '${_prefix}last_read'; // JSON map of path -> page
  static const _kContinuousScroll = '${_prefix}continuous_scroll'; // bool
  static const _kDarkReadingMode = '${_prefix}dark_reading_mode'; // bool
  static const _kShowThumbnails = '${_prefix}show_thumbnails'; // bool

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  // --- Theme ---
  String get themeMode => _prefs.getString(_kThemeMode) ?? 'system';
  Future<void> setThemeMode(String mode) =>
      _prefs.setString(_kThemeMode, mode);

  // --- Auto-encrypt ---
  bool get autoEncrypt => _prefs.getBool(_kAutoEncrypt) ?? false;
  Future<void> setAutoEncrypt(bool value) =>
      _prefs.setBool(_kAutoEncrypt, value);

  // --- User profile ---
  UserProfile get userProfile {
    final raw = _prefs.getString(_kUserProfile);
    if (raw == null) return const UserProfile();
    return UserProfile.fromJson(jsonDecode(raw));
  }

  Future<void> setUserProfile(UserProfile profile) =>
      _prefs.setString(_kUserProfile, jsonEncode(profile.toJson()));

  // --- Last read positions (per file) ---
  Map<String, int> get lastReadPositions {
    final raw = _prefs.getString(_kLastReadPositions);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  int? getLastReadPage(String path) => lastReadPositions[path];

  Future<void> setLastReadPage(String path, int page) async {
    final current = lastReadPositions;
    current[path] = page;
    await _prefs.setString(_kLastReadPositions, jsonEncode(current));
  }

  // --- Continuous scroll mode ---
  bool get continuousScroll => _prefs.getBool(_kContinuousScroll) ?? false;
  Future<void> setContinuousScroll(bool value) =>
      _prefs.setBool(_kContinuousScroll, value);

  // --- Dark reading mode ---
  bool get darkReadingMode => _prefs.getBool(_kDarkReadingMode) ?? false;
  Future<void> setDarkReadingMode(bool value) =>
      _prefs.setBool(_kDarkReadingMode, value);

  // --- Show thumbnails ---
  bool get showThumbnails => _prefs.getBool(_kShowThumbnails) ?? true;
  Future<void> setShowThumbnails(bool value) =>
      _prefs.setBool(_kShowThumbnails, value);

  // --- Migration from existing keys ---
  Future<void> migrateLegacyKeys() async {
    if (!_prefs.containsKey(_kLastDir)) {
      final oldDir = _prefs.getString('last_dir');
      if (oldDir != null) await _prefs.setString(_kLastDir, oldDir);
    }
  }
}
