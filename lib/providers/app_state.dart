import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/pdf_file.dart';
import '../services/file_service.dart';
import '../services/encryption_service.dart';
import '../providers/encryption_provider.dart';
import '../providers/settings_provider.dart';

enum SortBy { name, modified, size }
enum SortOrder { asc, desc }

enum SaveResult {
  success,
  alreadyExists,
  failure,
}

class AppState extends ChangeNotifier {
  // --- File browsing ---
  String? _currentDir;
  List<PdfFile> _files = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  // --- Recent files ---
  List<String> _recentFiles = [];
  static const int _maxRecentFiles = 5;
  static const String _recentFileName = 'recent_pdf_files.json';

  // --- Persistence ---
  String? _persistedDir;
  List<String> _scannedPaths = [];

  // --- Cache ---
  final _fileCache = <String, List<PdfFile>>{};

  // --- Sort ---
  SortBy _sortBy = SortBy.modified;
  SortOrder _sortOrder = SortOrder.desc;

  // --- Selected/opened file ---
  PdfFile? _selectedFile;

  // --- Encryption ---
  EncryptionProvider? _encryptionProvider;
  // ignore: unused_field
  SettingsProvider? _settingsProvider;

  void attachEncryption(EncryptionProvider provider) {
    _encryptionProvider = provider;
  }

  void attachSettings(SettingsProvider provider) {
    _settingsProvider = provider;
  }

  // --- Computed file list cache ---
  List<PdfFile>? _sortedFilteredFiles;
  int _fileListGeneration = 0;
  int _cachedFileListGeneration = -1;
  SortBy _lastSortBy = SortBy.modified;
  SortOrder _lastSortOrder = SortOrder.desc;
  String _lastSearchQuery = '';

  void _invalidateFileCache() {
    _fileListGeneration++;
    _sortedFilteredFiles = null;
    _recentFilesInDirCache = null;
  }

  // Getters
  String? get currentDir => _currentDir;
  List<PdfFile> get files {
    // Return cached result if inputs haven't changed
    if (_sortedFilteredFiles != null &&
        _cachedFileListGeneration == _fileListGeneration &&
        _lastSortBy == _sortBy &&
        _lastSortOrder == _sortOrder &&
        _lastSearchQuery == _searchQuery) {
      return _sortedFilteredFiles!;
    }

    var sorted = List<PdfFile>.from(_files);

    // Apply sorting
    sorted.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case SortBy.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case SortBy.modified:
          cmp = a.modified.compareTo(b.modified);
        case SortBy.size:
          cmp = a.sizeBytes.compareTo(b.sizeBytes);
      }
      return _sortOrder == SortOrder.asc ? cmp : -cmp;
    });

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      sorted = sorted.where((f) => f.name.toLowerCase().contains(q)).toList();
    }

    _sortedFilteredFiles = sorted;
    _cachedFileListGeneration = _fileListGeneration;
    _lastSortBy = _sortBy;
    _lastSortOrder = _sortOrder;
    _lastSearchQuery = _searchQuery;
    return sorted;
  }

  List<PdfFile> get allFiles => _files;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  List<String> get recentFilePaths => List.unmodifiable(_recentFiles);

  // --- Recent files in dir cache ---
  List<PdfFile>? _recentFilesInDirCache;
  int _cachedRecentGeneration = -1;
  int _lastRecentFilesLength = -1;

  List<PdfFile> get recentFilesInDir {
    if (_recentFilesInDirCache != null &&
        _cachedRecentGeneration == _fileListGeneration &&
        _lastRecentFilesLength == _recentFiles.length) {
      return _recentFilesInDirCache!;
    }

    final fileMap = {for (final f in _files) f.path: f};
    final result = _recentFiles
        .map((path) => fileMap[path])
        .whereType<PdfFile>()
        .toList();

    _recentFilesInDirCache = result;
    _cachedRecentGeneration = _fileListGeneration;
    _lastRecentFilesLength = _recentFiles.length;
    return result;
  }

  SortBy get sortBy => _sortBy;
  SortOrder get sortOrder => _sortOrder;

  set sortBy(SortBy value) {
    _sortBy = value;
    notifyListeners();
  }

  set sortOrder(SortOrder value) {
    _sortOrder = value;
    notifyListeners();
  }

  PdfFile? get selectedFile => _selectedFile;

  bool get hasFiles => _files.isNotEmpty;
  String get dirName => _currentDir != null
      ? _currentDir!.split('/').last
      : '';
  String? get persistedDir => _persistedDir;
  List<String> get scannedPaths => List.unmodifiable(_scannedPaths);

  // --- Directory loading ---
  Future<void> loadDirectory(String path) async {
    _isLoading = true;
    _error = null;
    _selectedFile = null;
    _currentDir = path;
    notifyListeners();

    try {
      final readable = await FileService.isReadable(path);
      if (!readable) {
        _error = 'Cannot read this directory';
        _isLoading = false;
        notifyListeners();
        return;
      }

      _files = _fileCache.containsKey(path)
          ? List.unmodifiable(_fileCache[path]!)
          : await FileService.scanDirectoryRecursive(path, maxDepth: 10);
      _fileCache[path] = List.unmodifiable(_files);
      _invalidateFileCache();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load directory: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- File operations ---
  void selectFile(PdfFile file) {
    _selectedFile = file;
    _addToRecent(file.path);
    _saveRecentFiles();
    notifyListeners();
  }

  void closeFile() {
    _selectedFile = null;
    notifyListeners();
  }

  Future<bool> deleteFile(PdfFile file) async {
    final success = await FileService.deleteFile(file.path);
    if (success) {
      _files.removeWhere((f) => f.path == file.path);
      _invalidateFileCache();
      // Invalidate cache for the containing directory
      final dir = FileService.parentDir(file.path);
      _fileCache.remove(dir);
      if (_selectedFile?.path == file.path) {
        _selectedFile = null;
      }
      notifyListeners();
    }
    return success;
  }

  /// Encrypt a PDF file (creating a .pdf.enc alongside it).
  /// Returns the new .pdf.enc path, or null on failure.
  Future<String?> encryptFile(PdfFile file) async {
    if (_encryptionProvider == null) return null;
    try {
      final encPath = await _encryptionProvider!.encryptFile(file.path);
      // Refresh the file in the list to include the new encrypted file
      final dir = FileService.parentDir(file.path);
      _fileCache.remove(dir);
      // Reload to pick up both original and encrypted file
      await loadDirectory(dir);
      return encPath;
    } on EncryptionException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  /// Auto-encrypt a PDF — write encrypted version, delete original.
  Future<bool> autoEncryptFile(PdfFile file) async {
    if (_encryptionProvider == null) return false;
    try {
      await _encryptionProvider!.encryptFile(file.path);
      await File(file.path).delete();
      // Refresh
      final dir = FileService.parentDir(file.path);
      _fileCache.remove(dir);
      await loadDirectory(dir);
      return true;
    } catch (e) {
      _error = 'Auto-encrypt failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Decrypt a .pdf.enc file to bytes for the viewer.
  Future<Uint8List?> decryptForViewing(PdfFile file) async {
    if (_encryptionProvider == null) return null;
    try {
      return await _encryptionProvider!.decryptFile(file.path);
    } on EncryptionException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  /// Read PDF bytes (non-encrypted) for the viewer.
  Future<Uint8List?> readPdfBytes(PdfFile file) async {
    try {
      return await FileService.readFileBytes(file.path);
    } catch (e) {
      _error = 'Failed to read file: $e';
      notifyListeners();
      return null;
    }
  }

  /// Get decrypted PDF bytes (handles both encrypted and unencrypted).
  Future<Uint8List?> getPdfBytes(PdfFile file) async {
    if (file.isEncrypted) {
      return await decryptForViewing(file);
    }
    return await readPdfBytes(file);
  }

  Future<void> shareFile(String path) async {
    try {
      final file = File(path);
      // For encrypted files, share the decrypted PDF
      if (path.endsWith('.pdf.enc') && _encryptionProvider != null) {
        final bytes = await _encryptionProvider!.decryptFile(path);
        final dir = await getTemporaryDirectory();
        final fileName = path.split('/').last;
        final pdfName = fileName.endsWith('.pdf.enc')
            ? fileName.substring(0, fileName.length - 4)
            : fileName;
        final tempFile = File('${dir.path}/$pdfName');
        await tempFile.writeAsBytes(bytes);
        final xFile = XFile(tempFile.path, mimeType: 'application/pdf');
        await Share.shareXFiles([xFile], text: pdfName);
      } else {
        // Share the file directly
        final xFile = XFile(path, mimeType: 'application/pdf');
        await Share.shareXFiles([xFile], text: file.uri.pathSegments.last);
      }
    } catch (e) {
      _error = 'Failed to share file: $e';
      notifyListeners();
    }
  }

  // --- Recent files persistence ---
  Future<void> loadRecentFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_recentFileName');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final data = jsonDecode(contents) as List<dynamic>;
        _recentFiles = data.cast<String>();
        _recentFilesInDirCache = null;
      }
    } catch (_) {
      // Ignore errors loading recent files
    }
  }

  Future<void> _saveRecentFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_recentFileName');
      await file.writeAsString(jsonEncode(_recentFiles));
    } catch (_) {
      // Ignore errors saving recent files
    }
  }

  void _addToRecent(String path) {
    _recentFiles.remove(path);
    _recentFiles.insert(0, path);
    if (_recentFiles.length > _maxRecentFiles) {
      _recentFiles = _recentFiles.sublist(0, _maxRecentFiles);
    }
    _recentFilesInDirCache = null;
  }

  // --- Search ---
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // --- Navigation ---
  void goToParentDir() {
    if (_currentDir != null) {
      final parent = FileService.parentDir(_currentDir!);
      loadDirectory(parent);
    }
  }

  // --- Multi-folder scanning ---
  Future<void> loadAllDirectories() async {
    if (_scannedPaths.isEmpty) {
      _files = [];
      _currentDir = null;
      _isLoading = false;
      _error = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    _selectedFile = null;
    _currentDir = _scannedPaths.first;
    notifyListeners();

    final results = await Future.wait(
      _scannedPaths.map((path) async {
        try {
          if (await FileService.isReadable(path)) {
            final dirFiles = _fileCache.containsKey(path)
                ? _fileCache[path]!
                : await FileService.scanDirectoryRecursive(path, maxDepth: 10);
            _fileCache[path] = List.unmodifiable(dirFiles);
            return dirFiles;
          }
        } catch (_) {}
        return <PdfFile>[];
      }),
    );
    _files = results.expand((list) => list).toList();
    _invalidateFileCache();
    _isLoading = false;
    notifyListeners();
  }

  // --- Persistence (SharedPreferences) ---
  Future<void> savePersistedDir(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_dir', path);
    _persistedDir = path;
  }

  Future<String?> loadPersistedDir() async {
    final prefs = await SharedPreferences.getInstance();
    _persistedDir = prefs.getString('last_dir');
    return _persistedDir;
  }

  Future<void> persistAfterPick(String path) async {
    await savePersistedDir(path);
    await addScannedPath(path);
  }

  Future<void> addScannedPath(String path) async {
    if (!_scannedPaths.contains(path)) {
      _scannedPaths.add(path);
      _scannedPaths.sort();
      await _saveScannedPaths();
    }
  }

  Future<List<String>> loadScannedPaths() async {
    final prefs = await SharedPreferences.getInstance();
    _scannedPaths = prefs.getStringList('scanned_paths') ?? [];
    return _scannedPaths;
  }

  Future<void> _saveScannedPaths() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('scanned_paths', _scannedPaths);
  }

  /// Get the folder name that contains this file.
  String getSourceDirName(String filePath) {
    for (final path in _scannedPaths) {
      if (filePath.startsWith(path)) {
        return path.split('/').last;
      }
    }
    return _currentDir?.split('/').last ?? '';
  }

  /// Save a file to a target directory, or the app's local documents MelodyPDF
  /// folder if [targetDir] is null.
  /// Returns a [SaveResult] indicating success, alreadyExists, or failure.
  Future<(SaveResult, String?)> saveToLocal(String sourcePath, {String? targetDir}) async {
    try {
      final String destDirPath;
      if (targetDir != null) {
        destDirPath = targetDir;
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        destDirPath = '${docsDir.path}/MelodyPDF';
      }

      final localDir = Directory(destDirPath);
      if (!await localDir.exists()) {
        await localDir.create(recursive: true);
      }

      final fileName = sourcePath.split('/').last;
      final destPath = '${localDir.path}/$fileName';

      // Check if file already exists locally
      if (await File(destPath).exists()) {
        return (SaveResult.alreadyExists, destPath);
      }

      // Copy file
      final sourceFile = File(sourcePath);
      await sourceFile.copy(destPath);

      // Add to scanned paths if not already there
      await addScannedPath(localDir.path);

      // Refresh file list
      await loadDirectory(localDir.path);

      return (SaveResult.success, destPath);
    } catch (e) {
      _error = 'Failed to save file: $e';
      notifyListeners();
      return (SaveResult.failure, null);
    }
  }

  // --- Refresh ---
  Future<void> refresh() async {
    _fileCache.clear();
    if (_scannedPaths.isNotEmpty) {
      await loadAllDirectories();
    } else if (_currentDir != null) {
      await loadDirectory(_currentDir!);
    }
  }
}
