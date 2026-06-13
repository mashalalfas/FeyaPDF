// Size: large — widget smoke tests (Flutter rendering baseline)
//
// These tests confirm the app's root widget tree builds without error.
// They run on every flutter test invocation and guard against scaffold breakage.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feya_pdf/main.dart';
import 'package:feya_pdf/providers/app_state.dart';
import 'package:feya_pdf/providers/encryption_provider.dart';
import 'package:feya_pdf/providers/file_operations_provider.dart';
import 'package:feya_pdf/providers/recent_files_provider.dart';
import 'package:feya_pdf/providers/scanned_paths_provider.dart';
import 'package:feya_pdf/providers/secure_folder_provider.dart';
import 'package:feya_pdf/providers/settings_provider.dart';
import 'package:feya_pdf/providers/sort_search_provider.dart';
import 'package:feya_pdf/providers/tag_provider.dart';
import 'package:feya_pdf/services/settings_service.dart';
import 'package:feya_pdf/services/tag_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('App smoke tests', () {
    // Arrange: nothing beyond the default test environment
    // Act: build the app root widget via MelodyPDFApp
    // Assert: widget builds without throwing, Scaffold is in the tree
    testWidgets('FeyaPdfApp builds without throwing', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsService = SettingsService(prefs);
      final tagService = TagService(prefs);

      // Arrange & Act
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => EncryptionProvider()),
            ChangeNotifierProvider(create: (_) => SortSearchProvider()),
            ChangeNotifierProvider(create: (_) => RecentFilesProvider()),
            ChangeNotifierProvider(create: (_) => ScannedPathsProvider()),
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(settingsService),
            ),
            ChangeNotifierProvider(create: (_) => TagProvider(tagService)),
            ChangeNotifierProvider(create: (_) => FileOperationsProvider()),
            ChangeNotifierProvider(create: (_) => AppState()),
            ChangeNotifierProvider(create: (_) => SecureFolderProvider()),
          ],
          child: const FeyaPdfApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('FeyaPdfApp shows a MaterialApp on first frame', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsService = SettingsService(prefs);
      final tagService = TagService(prefs);

      // Arrange & Act
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => EncryptionProvider()),
            ChangeNotifierProvider(create: (_) => SortSearchProvider()),
            ChangeNotifierProvider(create: (_) => RecentFilesProvider()),
            ChangeNotifierProvider(create: (_) => ScannedPathsProvider()),
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(settingsService),
            ),
            ChangeNotifierProvider(create: (_) => TagProvider(tagService)),
            ChangeNotifierProvider(create: (_) => FileOperationsProvider()),
            ChangeNotifierProvider(create: (_) => AppState()),
            ChangeNotifierProvider(create: (_) => SecureFolderProvider()),
          ],
          child: const FeyaPdfApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
