import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/bookmark.dart';
import '../models/highlight.dart';
import '../models/tag.dart';
import '../models/user_profile.dart';
import 'bookmark_service.dart';
import 'highlight_service.dart';
import 'settings_service.dart';
import 'tag_service.dart';

/// Collects all app state into a single JSON backup and restores it.
///
/// Backup format:
/// ```json
/// {
///   "metadata": { "version": 1, "exportedAt": "..." },
///   "data": {
///     "tags": [...],
///     "fileTagMap": { "path": ["tagId", ...] },
///     "highlights": [...],
///     "bookmarks": [...],
///     "settings": { ... },
///     "favorites": ["path", ...],
///     "recentFiles": ["path", ...],
///     "lastReadPositions": { "path": { "page": N, "total": N }, ... }
///   }
/// }
/// ```
class BackupService {
  final SettingsService settingsService;
  final TagService tagService;
  final HighlightService highlightService;
  final BookmarkService bookmarkService;

  BackupService({
    required this.settingsService,
    required this.tagService,
    required this.highlightService,
    required this.bookmarkService,
  });

  static const int _backupVersion = 1;

  /// Collect all state and return a formatted JSON string.
  ///
  /// [recentFilePaths] should come from [RecentFilesProvider.recentFilePaths].
  Future<String> exportAll({
    required List<String> recentFilePaths,
  }) async {
    final data = <String, dynamic>{
      'tags': tagService.getAllTags().map((t) => t.toJson()).toList(),
      'fileTagMap': tagService.getFileTagMap(),
      'highlights':
          highlightService.loadAll().map((h) => h.toJson()).toList(),
      'bookmarks': bookmarkService.loadAll().map((b) => b.toJson()).toList(),
      'settings': _exportSettings(),
      'favorites': settingsService.getFavorites().toList(),
      'recentFiles': recentFilePaths,
      'lastReadPositions': _exportLastReadPositions(),
    };

    final backup = <String, dynamic>{
      'metadata': <String, dynamic>{
        'version': _backupVersion,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
      },
      'data': data,
    };

    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  /// Parse a backup JSON string and restore all state.
  ///
  /// Returns `true` on success, `false` on schema version mismatch or
  /// unparseable data.
  Future<bool> importFromJson(String json) async {
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final metadata = decoded['metadata'] as Map<String, dynamic>;
      final version = metadata['version'] as int;

      if (version != _backupVersion) {
        return false;
      }

      final data = decoded['data'] as Map<String, dynamic>;

      // Order matters: tags before fileTagMap so IDs are valid.
      await _restoreTags(data['tags']);
      await _restoreFileTagMap(data['fileTagMap']);
      await _restoreHighlights(data['highlights']);
      await _restoreBookmarks(data['bookmarks']);
      await _restoreSettings(data['settings']);
      await _restoreFavorites(data['favorites']);
      await _restoreRecentFiles(data['recentFiles']);
      await _restoreLastReadPositions(data['lastReadPositions']);

      return true;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------
  // Settings export
  // ------------------------------------------------------------------

  Map<String, dynamic> _exportSettings() {
    return {
      'themeMode': settingsService.themeMode,
      'autoEncrypt': settingsService.autoEncrypt,
      'continuousScroll': settingsService.continuousScroll,
      'darkReadingMode': settingsService.darkReadingMode,
      'showThumbnails': settingsService.showThumbnails,
      'appLockEnabled': settingsService.appLockEnabled,
      'userProfile': settingsService.userProfile.toJson(),
    };
  }

  Map<String, dynamic> _exportLastReadPositions() {
    final raw = settingsService.lastReadPositions;
    // Build full-progress map from individual entries
    final result = <String, dynamic>{};
    for (final entry in raw.entries) {
      final progress = settingsService.getLastReadProgress(entry.key);
      if (progress != null) {
        result[entry.key] = {
          'page': progress.page,
          'total': progress.totalPages,
        };
      } else {
        result[entry.key] = {'page': entry.value, 'total': 0};
      }
    }
    return result;
  }

  // ------------------------------------------------------------------
  // Settings restore
  // ------------------------------------------------------------------

  Future<void> _restoreTags(dynamic raw) async {
    if (raw is! List) return;
    final tags = raw
        .cast<Map<String, dynamic>>()
        .map((j) => Tag.fromJson(j))
        .toList();
    await tagService.saveTags(tags);
  }

  Future<void> _restoreFileTagMap(dynamic raw) async {
    if (raw is! Map) return;
    final map = raw.map(
      (k, v) => MapEntry(
        k as String,
        (v as List).cast<String>().toList(),
      ),
    );
    await tagService.saveFileTagMap(map);
  }

  Future<void> _restoreHighlights(dynamic raw) async {
    if (raw is! List) return;
    final highlights =
        raw.cast<Map<String, dynamic>>().map(HighlightData.fromJson).toList();
    // Group by file path and save per file
    final byFile = <String, List<HighlightData>>{};
    for (final h in highlights) {
      byFile.putIfAbsent(h.filePath, () => []).add(h);
    }
    for (final entry in byFile.entries) {
      await highlightService.saveForFile(entry.key, entry.value);
    }
  }

  Future<void> _restoreBookmarks(dynamic raw) async {
    if (raw is! List) return;
    final bookmarks =
        raw.cast<Map<String, dynamic>>().map(Bookmark.fromJson).toList();
    // Group by file path and save per file
    final byFile = <String, List<Bookmark>>{};
    for (final b in bookmarks) {
      byFile.putIfAbsent(b.filePath, () => []).add(b);
    }
    for (final entry in byFile.entries) {
      await bookmarkService.saveForFile(entry.key, entry.value);
    }
  }

  Future<void> _restoreSettings(dynamic raw) async {
    if (raw is! Map) return;
    if (raw.containsKey('themeMode')) {
      await settingsService.setThemeMode(raw['themeMode'] as String);
    }
    if (raw.containsKey('autoEncrypt')) {
      await settingsService.setAutoEncrypt(raw['autoEncrypt'] as bool);
    }
    if (raw.containsKey('continuousScroll')) {
      await settingsService.setContinuousScroll(
        raw['continuousScroll'] as bool,
      );
    }
    if (raw.containsKey('darkReadingMode')) {
      await settingsService.setDarkReadingMode(raw['darkReadingMode'] as bool);
    }
    if (raw.containsKey('showThumbnails')) {
      await settingsService.setShowThumbnails(raw['showThumbnails'] as bool);
    }
    if (raw.containsKey('appLockEnabled')) {
      await settingsService.setAppLockEnabled(raw['appLockEnabled'] as bool);
    }
    if (raw.containsKey('userProfile') && raw['userProfile'] is Map) {
      final profile = UserProfile.fromJson(raw['userProfile']);
      await settingsService.setUserProfile(profile);
    }
  }

  Future<void> _restoreFavorites(dynamic raw) async {
    if (raw is! List) return;
    final paths = raw.cast<String>();

    // Remove existing favorites that are not in the restored set
    final existing = settingsService.getFavorites();
    for (final path in existing) {
      if (!paths.contains(path)) {
        await settingsService.setFavorite(path, false);
      }
    }
    // Add restored favorites
    for (final path in paths) {
      if (!existing.contains(path)) {
        await settingsService.setFavorite(path, true);
      }
    }
  }

  Future<void> _restoreRecentFiles(dynamic raw) async {
    if (raw is! List) return;
    try {
      final paths = raw.cast<String>();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/recent_pdf_files.json');
      await file.writeAsString(jsonEncode(paths));
    } catch (_) {
      // Best-effort: recent files are non-critical
    }
  }

  Future<void> _restoreLastReadPositions(dynamic raw) async {
    if (raw is! Map) return;
    final map = raw as Map<String, dynamic>;
    for (final entry in map.entries) {
      final path = entry.key;
      final val = entry.value;
      if (val is Map) {
        final page = (val['page'] as int?) ?? 0;
        final total = (val['total'] as int?) ?? 0;
        await settingsService.setLastReadPage(path, page, total);
      } else if (val is int) {
        await settingsService.setLastReadPage(path, val, 0);
      }
    }
  }
}
