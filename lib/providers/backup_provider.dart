import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/backup_service.dart';
import 'bookmark_provider.dart';
import 'favorites_provider.dart';
import 'highlight_provider.dart';
import 'recent_files_provider.dart';
import 'settings_provider.dart';
import 'tag_provider.dart';

/// Manages backup export/import UI and orchestration.
class BackupProvider extends ChangeNotifier {
  final BackupService _backupService;

  bool _isExporting = false;
  bool _isImporting = false;
  String? _lastExportPath;

  BackupProvider(this._backupService);

  // ---- Getters ----

  bool get isExporting => _isExporting;
  bool get isImporting => _isImporting;
  String? get lastExportPath => _lastExportPath;

  // ---- Export ----

  /// Collect all app state, save to a JSON file, and share it.
  Future<void> exportBackup(BuildContext context) async {
    if (_isExporting) return;
    _isExporting = true;
    notifyListeners();

    try {
      // Gather data from all providers
      final recentFilesProvider = context.read<RecentFilesProvider>();

      final json = await _backupService.exportAll(
        recentFilePaths: recentFilesProvider.recentFilePaths.toList(),
      );

      // Write to a temp file
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${dir.path}/FeyaPDF_backup_$timestamp.json';
      final file = File(filePath);
      await file.writeAsString(json);

      _lastExportPath = filePath;

      // Share the backup file
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'FeyaPDF Backup',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup saved: FeyaPDF_backup_$timestamp.json'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  // ---- Import ----

  /// Pick a backup JSON file, confirm with the user, then restore.
  Future<void> importBackup(BuildContext context) async {
    if (_isImporting) return;

    // Step 1: Pick a file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    // Step 2: Read the file
    String json;
    try {
      json = await File(filePath).readAsString();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read backup file: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    // Step 3: Parse and build summary for confirmation dialog
    Map<String, dynamic>? parsed;
    try {
      parsed = jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      // Let the service handle parsing errors
    }

    // Quick summary
    int tagCount = 0;
    int highlightCount = 0;
    int bookmarkCount = 0;
    int favoriteCount = 0;
    int recentFileCount = 0;

    if (parsed != null) {
      final data = parsed['data'] as Map<String, dynamic>?;
      if (data != null) {
        tagCount = _listLength(data['tags']);
        highlightCount = _listLength(data['highlights']);
        bookmarkCount = _listLength(data['bookmarks']);
        favoriteCount = _listLength(data['favorites']);
        recentFileCount = _listLength(data['recentFiles']);
      }
    }

    // Step 4: Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Restore Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will replace your current data with the backup.',
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            _summaryRow(ctx, 'Tags', tagCount),
            _summaryRow(ctx, 'Highlights', highlightCount),
            _summaryRow(ctx, 'Bookmarks', bookmarkCount),
            _summaryRow(ctx, 'Favorites', favoriteCount),
            _summaryRow(ctx, 'Recent files', recentFileCount),
            const SizedBox(height: 8),
            Text(
              'Settings and last-read positions will also be restored.',
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Step 5: Perform the import
    _isImporting = true;
    notifyListeners();

    try {
      final success = await _backupService.importFromJson(json);

      if (success) {
        // Reload all providers with fresh data
        if (context.mounted) {
          context.read<HighlightProvider>().reload();
          context.read<BookmarkProvider>().reload();
          context.read<SettingsProvider>().reload();
          context.read<FavoritesProvider>().reload();
          context.read<TagProvider>().reload();
          await context.read<RecentFilesProvider>().loadRecentFiles();
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Backup restored successfully'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Failed to restore backup: incompatible schema version',
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  // ---- Helpers ----

  int _listLength(dynamic value) {
    if (value is List) return value.length;
    if (value is Map) return value.length;
    return 0;
  }

  Widget _summaryRow(BuildContext context, String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text('$label: '),
          Text(
            '$count',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
