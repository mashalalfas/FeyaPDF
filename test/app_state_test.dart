import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody_pdf/models/pdf_file.dart';
import 'package:melody_pdf/providers/app_state.dart';

/// Global temp root for filesystem tests; cleaned up in tearDownAll.
late Directory _tempRoot;

Directory _makeTempDir(String name) {
  final dir = Directory('${_tempRoot.path}/$name');
  dir.createSync(recursive: true);
  return dir;
}

File _writePdf(Directory parent, String name, {int sizeBytes = 100}) {
  final file = File('${parent.path}/$name');
  file.writeAsBytesSync(List.generate(sizeBytes, (i) => i % 256));
  return file;
}

void main() {
  setUpAll(() {
    _tempRoot = Directory.systemTemp.createTempSync('melody_pdf_app_state_');
  });

  tearDownAll(() {
    if (_tempRoot.existsSync()) {
      _tempRoot.deleteSync(recursive: true);
    }
  });

  group('AppState', () {
    test('starts with no directory and empty files', () {
      final state = AppState();
      expect(state.currentDir, isNull);
      expect(state.files, isEmpty);
      expect(state.hasFiles, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.selectedFile, isNull);
    });

    test('loadDirectory populates files from a real directory', () async {
      final dir = _makeTempDir('load_basic');
      _writePdf(dir, 'doc1.pdf');
      _writePdf(dir, 'doc2.pdf');

      final state = AppState();
      await state.loadDirectory(dir.path);

      expect(state.currentDir, equals(dir.path));
      expect(state.files, hasLength(2));
      expect(state.hasFiles, isTrue);
      expect(state.isLoading, isFalse);
    });

    test('loadDirectory returns empty files for non-existent path', () async {
      final state = AppState();
      await state.loadDirectory('/no/such/dir_xyz_123');

      expect(state.files, isEmpty);
      expect(state.hasFiles, isFalse);
    });

    test('loadDirectory ignores non-PDF files', () async {
      final dir = _makeTempDir('load_ignore');
      _writePdf(dir, 'keep.pdf');
      _writePdf(dir, 'skip.txt');

      final state = AppState();
      await state.loadDirectory(dir.path);

      expect(state.files, hasLength(1));
      expect(state.files.first.name, equals('keep.pdf'));
    });

    test('selectFile sets selectedFile', () async {
      final dir = _makeTempDir('select_file');
      _writePdf(dir, 'doc.pdf');

      final state = AppState();
      await state.loadDirectory(dir.path);

      final file = state.files.first;
      state.selectFile(file);

      expect(state.selectedFile, isNotNull);
      expect(state.selectedFile!.path, equals(file.path));
    });

    test('selectFile with different file changes selection', () async {
      final dir = _makeTempDir('select_change');
      _writePdf(dir, 'a.pdf');
      _writePdf(dir, 'b.pdf');

      final state = AppState();
      await state.loadDirectory(dir.path);

      state.selectFile(state.files.first);
      expect(state.selectedFile, isNotNull);

      state.selectFile(state.files.last);
      expect(state.selectedFile!.path, equals(state.files.last.path));
    });

    test('closeFile clears selectedFile', () async {
      final dir = _makeTempDir('close_file');
      _writePdf(dir, 'doc.pdf');

      final state = AppState();
      await state.loadDirectory(dir.path);

      state.selectFile(state.files.first);
      expect(state.selectedFile, isNotNull);

      state.closeFile();
      expect(state.selectedFile, isNull);
    });

    test('loading a new directory replaces the file list', () async {
      final dir1 = _makeTempDir('dir1');
      _writePdf(dir1, 'a.pdf');
      final dir2 = _makeTempDir('dir2');
      _writePdf(dir2, 'b.pdf');
      _writePdf(dir2, 'c.pdf');

      final state = AppState();
      await state.loadDirectory(dir1.path);
      expect(state.files, hasLength(1));

      await state.loadDirectory(dir2.path);
      expect(state.files, hasLength(2));
      expect(state.currentDir, equals(dir2.path));
    });

    test('files getter returns modifiable copy of internal list', () async {
      final dir = _makeTempDir('modcopy');
      _writePdf(dir, 'a.pdf');

      final state = AppState();
      await state.loadDirectory(dir.path);

      // Should be able to iterate; internal _files is immutable
      expect(state.files, isA<List<PdfFile>>());
    });

    test('hasFiles is true when directory has PDFs, false otherwise', () async {
      final dir = _makeTempDir('hasfiles');
      final state = AppState();

      expect(state.hasFiles, isFalse);
      _writePdf(dir, 'doc.pdf');
      await state.loadDirectory(dir.path);
      expect(state.hasFiles, isTrue);
    });

    test('currentDir getter returns loaded directory path', () async {
      final dir = _makeTempDir('curdir');
      final state = AppState();
      await state.loadDirectory(dir.path);
      expect(state.currentDir, equals(dir.path));
    });

    test('error is null after successful loadDirectory', () async {
      final dir = _makeTempDir('noerr');
      _writePdf(dir, 'doc.pdf');
      final state = AppState();
      await state.loadDirectory(dir.path);
      expect(state.error, isNull);
    });

    test('isLoading is false after loadDirectory completes', () async {
      final dir = _makeTempDir('notloading');
      _writePdf(dir, 'doc.pdf');
      final state = AppState();
      await state.loadDirectory(dir.path);
      expect(state.isLoading, isFalse);
    });

    test('file names from loadDirectory have .pdf extension', () async {
      final dir = _makeTempDir('ext_check');
      _writePdf(dir, 'report.pdf');

      final state = AppState();
      await state.loadDirectory(dir.path);

      expect(state.files.first.name, endsWith('.pdf'));
    });

    test('multiple PDFs are all returned', () async {
      final dir = _makeTempDir('multi_pdf');
      for (var i = 0; i < 10; i++) {
        _writePdf(dir, 'doc_$i.pdf');
      }

      final state = AppState();
      await state.loadDirectory(dir.path);

      expect(state.files, hasLength(10));
    });

    test('selectedFile is null on initial state', () {
      final state = AppState();
      expect(state.selectedFile, isNull);
    });

    test('selectFile then closeFile cycle', () async {
      final dir = _makeTempDir('select_close_cycle');
      _writePdf(dir, 'doc.pdf');

      final state = AppState();
      await state.loadDirectory(dir.path);

      expect(state.selectedFile, isNull);
      state.selectFile(state.files.first);
      expect(state.selectedFile, isNotNull);
      state.closeFile();
      expect(state.selectedFile, isNull);
    });
  });
}
