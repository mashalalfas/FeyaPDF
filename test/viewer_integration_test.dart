// Size: large — widget integration tests for ViewerScreen
// (Flutter rendering, pumpWidget, finders — slower than service tests)
//
// Coverage breakdown (target 5% E2E/widget):
//   Loading state:   1 test — CircularProgressIndicator visible before _loadPdf completes
//   Error state:     1 test — error icon + retry button for missing file
//   Retry button:    1 test — retry resets state via setState
//   SVG branch:      1 test — .svg file renders SvgPicture widget
//   AppBar title:    1 test — encrypted file shows lock icon and displayName
//   Decrypt failure: 1 test — encrypted file without passphrase shows error
//   Total:           6 tests

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:melody_pdf/models/pdf_file.dart';
import 'package:melody_pdf/providers/app_state.dart';
import 'package:melody_pdf/providers/encryption_provider.dart';
import 'package:melody_pdf/providers/file_operations_provider.dart';
import 'package:melody_pdf/providers/settings_provider.dart';
import 'package:melody_pdf/screens/viewer_screen.dart';
import 'package:melody_pdf/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Temp root for filesystem fixtures used in widget tests.
late Directory _tempRoot;

Directory _makeTempDir(String name) {
  final dir = Directory('${_tempRoot.path}/$name');
  dir.createSync(recursive: true);
  return dir;
}

PdfFile _pdfFileAt(Directory dir, String name,
    {bool encrypted = false, int sizeBytes = 100}) {
  return PdfFile(
    path: '${dir.path}/$name',
    name: name,
    sizeBytes: sizeBytes,
    modified: DateTime.now(),
  );
}

/// Pump ViewerScreen inside a MultiProvider and return the EncryptionProvider
/// instance so tests can call setPassphrase() before load completes.
Future<EncryptionProvider> _pumpViewer(
  WidgetTester tester, {
  required PdfFile file,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final encProvider = EncryptionProvider();
  final settingsProvider = SettingsProvider(SettingsService(prefs));

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<EncryptionProvider>.value(value: encProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<FileOperationsProvider>(
          create: (_) => FileOperationsProvider(),
        ),
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
        ),
      ],
      child: MaterialApp(
        home: ViewerScreen(file: file),
      ),
    ),
  );

  return encProvider;
}

void main() {
  setUpAll(() {
    _tempRoot = Directory.systemTemp.createTempSync('melody_pdf_viewer_');
  });

  tearDownAll(() {
    if (_tempRoot.existsSync()) _tempRoot.deleteSync(recursive: true);
  });

  group('ViewerScreen — loading state', () {
    // Arrange: existing temp PDF; pump ViewerScreen
    // Act: pump one frame — _loadPdf is async and not yet complete
    // Assert: CircularProgressIndicator is in the tree while _isLoading is true

    testWidgets('shows CircularProgressIndicator while PDF is loading',
        (tester) async {
      // Arrange
      final dir = _makeTempDir('loading_pdf');
      final file = _pdfFileAt(dir, 'loading.pdf');
      File(file.path).writeAsBytesSync([1, 2, 3]);

      // Act — pump only one frame; async _loadPdf hasn't completed yet
      await _pumpViewer(tester, file: file);
      await tester.pump();

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('ViewerScreen — error state', () {
    // Arrange: PdfFile pointing to a path that does NOT exist on disk
    // Act: pump widget, pumpAndSettle to let _loadPdf finish
    // Assert: error icon (Icons.error_outline_rounded) visible,
    //         retry FilledButton present

    testWidgets('shows error icon and retry button when PDF file is missing',
        (tester) async {
      // Arrange — path that does not exist on disk
      final dir = _makeTempDir('error_nofile');
      final file = _pdfFileAt(dir, 'nonexistent.pdf');

      // Act
      await _pumpViewer(tester, file: file);
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    // Arrange: missing file → error state, tap retry button
    // Act: tap FilledButton then pumpAndSettle (file still missing)
    // Assert: error icon returns (state was reset then re-error)

    testWidgets('retry button resets state and re-runs _loadPdf', (tester) async {
      // Arrange
      final dir = _makeTempDir('retry_nofile');
      final file = _pdfFileAt(dir, 'retry_nonexistent.pdf');

      await _pumpViewer(tester, file: file);
      await tester.pumpAndSettle();

      // Confirm error state before retry
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      // Act — tap the retry button; onPressed resets _isLoading/_error and calls _loadPdf
      await tester.tap(find.byType(FilledButton));
      await tester.pump(); // setState fires immediately in onPressed
      await tester.pumpAndSettle(); // _loadPdf completes (file still missing)

      // Assert — error icon is back (file still doesn't exist)
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });
  });

  group('ViewerScreen — SVG branch', () {
    // Arrange: PdfFile ending in .svg, file exists on disk with valid SVG content
    // Act: pump widget, pumpAndSettle
    // Assert: SvgPicture widget is in the tree (SVG branch rendered)

    testWidgets('renders SvgPicture widget for a .svg file', (tester) async {
      // Arrange
      final dir = _makeTempDir('svg_file');
      final svgPath = '${dir.path}/diagram.svg';
      File(svgPath).writeAsStringSync(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<circle cx="50" cy="50" r="40" fill="blue"/></svg>',
      );
      final file = PdfFile(
        path: svgPath,
        name: 'diagram.svg',
        sizeBytes: 150,
        modified: DateTime.now(),
      );

      // Act
      await _pumpViewer(tester, file: file);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Assert — SvgPicture widget rendered (SVG branch active)
      expect(find.byType(SvgPicture), findsOneWidget);
    });
  });

  group('ViewerScreen — AppBar for encrypted files', () {
    // Arrange: encrypted PdfFile (.pdf.enc), pump ViewerScreen
    // Act: pump one frame
    // Assert: lock icon in AppBar, displayName without .enc suffix

    testWidgets('shows lock icon and displayName for an encrypted file',
        (tester) async {
      // Arrange
      final dir = _makeTempDir('enc_appbar');
      final file = _pdfFileAt(dir, 'secret.pdf.enc', encrypted: true);
      File(file.path).writeAsBytesSync([1, 2, 3]);

      // Act
      await _pumpViewer(tester, file: file);
      await tester.pump();

      // Assert
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      // displayName strips .enc: 'secret.pdf.enc' → 'secret.pdf'
      expect(find.text('secret.pdf'), findsOneWidget);
    });

    testWidgets('AppBar title does not show .enc suffix for encrypted file',
        (tester) async {
      // Arrange
      final dir = _makeTempDir('enc_name');
      final file = _pdfFileAt(dir, 'report.pdf.enc', encrypted: true);
      File(file.path).writeAsBytesSync([4, 5, 6]);

      // Act
      await _pumpViewer(tester, file: file);
      await tester.pump();

      // Assert
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('report.pdf.enc'), findsNothing);
    });
  });

  group('ViewerScreen — decryption failure path', () {
    // Arrange: encrypted PdfFile (.pdf.enc), EncryptionProvider WITH a passphrase set
    // but the file bytes are NOT actually encrypted with that passphrase.
    // Act: pump widget, pump a frame for async _loadPdf to complete
    // Assert: error icon visible, error message mentions 'Decryption' or 'wrong passphrase'

    testWidgets(
        'shows decryption error when encrypted file has wrong/invalid contents',
        (tester) async {
      // Arrange — file is .pdf.enc but content is random bytes, not encrypted
      final dir = _makeTempDir('decrypt_fail');
      final file = _pdfFileAt(dir, 'locked.pdf.enc', encrypted: true);
      // Write random bytes — NOT a valid .pdf.enc for passphrase 'nope'
      File(file.path).writeAsBytesSync([7, 8, 9]);

      final encProvider = await _pumpViewer(tester, file: file);
      // Set a passphrase — the file is NOT encrypted with it, so decrypt will fail
      encProvider.setPassphrase('test-passphrase-123');

      // Act — _loadPdf runs: sees isEncrypted && hasPassphrase → calls decrypt
      // decryptFile throws EncryptionException → getPdfBytes returns null → error state
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Assert
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('Decryption failed — wrong passphrase?'), findsOneWidget);
    });
  });
}
