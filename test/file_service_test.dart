import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody_pdf/services/file_service.dart';

// We use a dedicated temp root per test run to avoid cross-test contamination.
late Directory _tempRoot;

Directory _makeTempDir(String name) {
  final dir = Directory('${_tempRoot.path}/$name');
  dir.createSync(recursive: true);
  return dir;
}

/// Helper: write a file with [name] and [content] under [parent].
File _writeFile(Directory parent, String name, List<int> content) {
  final file = File('${parent.path}/$name');
  file.writeAsBytesSync(content);
  return file;
}

void main() {
  setUpAll(() {
    _tempRoot = Directory.systemTemp.createTempSync('melody_pdf_fs_test_');
  });

  tearDownAll(() {
    if (_tempRoot.existsSync()) {
      _tempRoot.deleteSync(recursive: true);
    }
  });

  group('FileService.scanDirectory', () {
    test('finds .pdf files, ignores non-PDF files', () async {
      final dir = _makeTempDir('scan_basic');
      _writeFile(dir, 'a.pdf', [1, 2, 3]);
      _writeFile(dir, 'b.pdf', [4, 5, 6]);
      _writeFile(dir, 'c.txt', [7, 8, 9]);
      _writeFile(dir, 'd.jpg', [10, 11, 12]);
      _writeFile(dir, 'e.pdf.enc', [13, 14, 15]); // encrypted — also accepted

      final files = await FileService.scanDirectory(dir.path);
      final names = files.map((f) => f.name).toList();

      expect(names, contains('a.pdf'));
      expect(names, contains('b.pdf'));
      expect(names, contains('e.pdf.enc'));
      expect(names, isNot(contains('c.txt')));
      expect(names, isNot(contains('d.jpg')));
      expect(files.length, equals(3));
    });

    test('returns empty list for non-existent directory', () async {
      final files = await FileService.scanDirectory('/nonexistent/path/xyz');
      expect(files, isEmpty);
    });

    test('returns empty list for empty directory', () async {
      final dir = _makeTempDir('empty_dir');
      final files = await FileService.scanDirectory(dir.path);
      expect(files, isEmpty);
    });

    test('results are sorted by modified time newest first', () async {
      final dir = _makeTempDir('sort_test');
      _writeFile(dir, 'old.pdf', [1]);
      // Brief pause to ensure distinct modified times
      await Future.delayed(const Duration(milliseconds: 1100));
      _writeFile(dir, 'new.pdf', [2]);

      final files = await FileService.scanDirectory(dir.path);
      expect(files.length, equals(2));
      expect(files.first.name, equals('new.pdf'));
    });
  });

  group('FileService.scanDirectoryRecursive', () {
    test('finds PDFs in subdirectories', () async {
      final root = _makeTempDir('recursive_root');
      _writeFile(root, 'root.pdf', [1]);
      final sub1 = _makeTempDir('recursive_root/sub1');
      _writeFile(sub1, 'sub1.pdf', [2]);
      final sub2 = _makeTempDir('recursive_root/sub1/sub2');
      _writeFile(sub2, 'sub2.pdf', [3]);

      final files = await FileService.scanDirectoryRecursive(root.path);
      final names = files.map((f) => f.name).toList();
      expect(names, containsAll(['root.pdf', 'sub1.pdf', 'sub2.pdf']));
      expect(files.length, equals(3));
    });

    test('returns empty list for non-existent directory', () async {
      final files = await FileService.scanDirectoryRecursive('/no/such/dir');
      expect(files, isEmpty);
    });

    test('ignores non-PDF files in subdirectories', () async {
      final root = _makeTempDir('recursive_ignore');
      _writeFile(root, 'keep.pdf', [1]);
      _makeTempDir('recursive_ignore/empty_sub'); // dir with no files
      final sub = _makeTempDir('recursive_ignore/sub_with_txt');
      _writeFile(sub, 'skip.txt', [2]);

      final files = await FileService.scanDirectoryRecursive(root.path);
      expect(files.length, equals(1));
      expect(files.first.name, equals('keep.pdf'));
    });
  });

  group('FileService.deleteFile', () {
    test('deletes existing file and returns true', () async {
      final dir = _makeTempDir('del_test');
      final file = _writeFile(dir, 'delete_me.pdf', [1, 2, 3]);
      expect(file.existsSync(), isTrue);

      final result = await FileService.deleteFile(file.path);
      expect(result, isTrue);
      expect(file.existsSync(), isFalse);
    });

    test('returns false for already-deleted file', () async {
      final dir = _makeTempDir('del_missing');
      final path = '${dir.path}/missing.pdf';
      final result = await FileService.deleteFile(path);
      expect(result, isFalse);
    });
  });

  group('FileService.isReadable', () {
    test('returns true for existing readable directory', () async {
      final dir = _makeTempDir('readable');
      final result = await FileService.isReadable(dir.path);
      expect(result, isTrue);
    });

    test('returns false for non-existent path', () async {
      final result = await FileService.isReadable('/no/such/path_xyz');
      expect(result, isFalse);
    });
  });

  group('FileService.readFileBytes', () {
    test('returns correct content for an existing file', () async {
      final dir = _makeTempDir('read_bytes');
      final content = [10, 20, 30, 40, 50];
      final file = _writeFile(dir, 'data.pdf', content);

      final bytes = await FileService.readFileBytes(file.path);
      expect(bytes, equals(content));
    });
  });
}
