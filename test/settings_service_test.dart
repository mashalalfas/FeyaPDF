import 'package:flutter_test/flutter_test.dart';
import 'package:melody_pdf/models/user_profile.dart';
import 'package:melody_pdf/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsService', () {
    // Seed an empty mock once; getInstance() returns the same singleton.
    setUpAll(() {
      SharedPreferences.setMockInitialValues({});
    });

    late SharedPreferences prefs;
    late SettingsService service;

    setUp(() async {
      prefs = await SharedPreferences.getInstance();
      // Clear all keys between tests by removing them individually
      if (prefs.getKeys().isNotEmpty) {
        // Remove everything to start fresh
        for (final key in prefs.getKeys().toList()) {
          await prefs.remove(key);
        }
      }
      service = SettingsService(prefs);
    });

    // --- Theme ---
    test('themeMode defaults to system when not set', () {
      expect(service.themeMode, equals('system'));
    });

    test('setThemeMode persists and returns the set value', () async {
      await service.setThemeMode('dark');
      expect(service.themeMode, equals('dark'));
    });

    test('setThemeMode can be read back after multiple sets', () async {
      await service.setThemeMode('light');
      expect(service.themeMode, equals('light'));
      await service.setThemeMode('dark');
      expect(service.themeMode, equals('dark'));
    });

    // --- Auto-encrypt ---
    test('autoEncrypt defaults to false when not set', () {
      expect(service.autoEncrypt, isFalse);
    });

    test('setAutoEncrypt true persists', () async {
      await service.setAutoEncrypt(true);
      expect(service.autoEncrypt, isTrue);
    });

    test('setAutoEncrypt false persists', () async {
      await service.setAutoEncrypt(true);
      await service.setAutoEncrypt(false);
      expect(service.autoEncrypt, isFalse);
    });

    // --- User profile ---
    test('userProfile returns default when not set', () {
      expect(service.userProfile, equals(const UserProfile()));
    });

    test('setUserProfile persists and returns correct values', () async {
      final profile = UserProfile(name: 'Max', email: 'max@example.com');
      await service.setUserProfile(profile);
      expect(service.userProfile.name, equals('Max'));
      expect(service.userProfile.email, equals('max@example.com'));
    });

    test('setUserProfile with null avatarPath', () async {
      final profile = const UserProfile(name: 'Alice', email: 'alice@test.com');
      await service.setUserProfile(profile);
      final loaded = service.userProfile;
      expect(loaded.name, equals('Alice'));
      expect(loaded.avatarPath, isNull);
    });

    // --- Last read page ---
    test('lastReadPositions defaults to empty map', () {
      expect(service.lastReadPositions, isEmpty);
    });

    test('setLastReadPage persists and getLastReadPage retrieves it', () async {
      await service.setLastReadPage('/path/to/file.pdf', 42);
      expect(service.getLastReadPage('/path/to/file.pdf'), equals(42));
    });

    test('setLastReadPage updates existing entry', () async {
      await service.setLastReadPage('/path/a.pdf', 10);
      await service.setLastReadPage('/path/a.pdf', 25);
      expect(service.getLastReadPage('/path/a.pdf'), equals(25));
    });

    test('setLastReadPage handles multiple files independently', () async {
      await service.setLastReadPage('/a.pdf', 5);
      await service.setLastReadPage('/b.pdf', 15);
      await service.setLastReadPage('/c.pdf', 99);
      expect(service.getLastReadPage('/a.pdf'), equals(5));
      expect(service.getLastReadPage('/b.pdf'), equals(15));
      expect(service.getLastReadPage('/c.pdf'), equals(99));
    });

    test('getLastReadPage returns null for unknown file', () {
      expect(service.getLastReadPage('/unknown.pdf'), isNull);
    });

    // --- Legacy migration ---
    test('migrateLegacyKeys copies old last_dir key', () async {
      await prefs.setString('last_dir', '/legacy/path');
      await service.migrateLegacyKeys();
      expect(prefs.getString('mely_pdf_last_dir'), equals('/legacy/path'));
    });

    test('migrateLegacyKeys does not overwrite existing new key', () async {
      await prefs.setString('last_dir', '/old/path');
      await prefs.setString('mely_pdf_last_dir', '/new/path');
      await service.migrateLegacyKeys();
      expect(prefs.getString('mely_pdf_last_dir'), equals('/new/path'));
    });

    test('migrateLegacyKeys does nothing when old key absent', () async {
      await prefs.setString('mely_pdf_last_dir', '/already/set');
      await service.migrateLegacyKeys();
      expect(prefs.getString('mely_pdf_last_dir'), equals('/already/set'));
    });

    // --- Combined operations ---
    test('multiple settings can be set and read independently', () async {
      await service.setThemeMode('dark');
      await service.setAutoEncrypt(true);
      await service.setLastReadPage('/doc.pdf', 7);

      expect(service.themeMode, equals('dark'));
      expect(service.autoEncrypt, isTrue);
      expect(service.getLastReadPage('/doc.pdf'), equals(7));
    });
  });
}
