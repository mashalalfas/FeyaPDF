import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_state.dart';
import '../providers/encryption_provider.dart';
import '../providers/tag_provider.dart';
import '../providers/sort_search_provider.dart';
import '../providers/file_operations_provider.dart';
import '../providers/recent_files_provider.dart';
import '../providers/scanned_paths_provider.dart';
import '../models/pdf_file.dart';
import '../widgets/file_list_tile.dart';
import '../widgets/tag_chip.dart';
import '../widgets/tag_picker_dialog.dart';
import '../widgets/encryption_badge.dart';
import '../widgets/passphrase_dialog.dart';
import '../widgets/secure_folder_card.dart';
import '../services/permission_service.dart';
import '../services/intent_handler.dart';
import 'viewer_screen.dart';
import 'settings_screen.dart';
import 'tags_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  bool _showSearch = false;
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final appState = context.read<AppState>();
    final recentProvider = context.read<RecentFilesProvider>();
    final pathsProvider = context.read<ScannedPathsProvider>();

    await recentProvider.loadRecentFiles();
    await pathsProvider.loadScannedPaths();

    final persisted = await pathsProvider.loadPersistedDir();
    bool loaded = false;
    if (persisted != null && await Directory(persisted).exists()) {
      await appState.loadDirectory(persisted);
      loaded = appState.allFiles.isNotEmpty || appState.error != null;
    }
    if (!loaded && pathsProvider.scannedPaths.isNotEmpty) {
      await appState.loadAllDirectories(pathsProvider.scannedPaths);
    }
    if (mounted) {
      _staggerController.forward();
    }

    // Check if app was launched via "Open with" intent
    _checkInitialIntent();

    // Listen for future intents
    IntentHandler.onFileOpened.listen((path) {
      if (mounted) _openFileFromPath(path);
    });
  }

  void _checkInitialIntent() async {
    final path = await IntentHandler.getInitialFilePath();
    if (path != null && mounted) {
      _openFileFromPath(path);
    }
  }

  void _openFileFromPath(String path) {
    final appState = context.read<AppState>();
    // Find file in loaded files, or create a transient one for direct open
    final existing = appState.files.where((f) => f.path == path).toList();
    if (existing.isNotEmpty) {
      _openFile(existing.first);
    } else {
      // File not in scanned list — create a transient PdfFile and open directly
      final file = File(path);
      if (file.existsSync()) {
        final pdfFile = PdfFile(
          path: path,
          name: path.split('/').last,
          sizeBytes: file.lengthSync(),
          modified: file.lastModifiedSync(),
        );
        _openFile(pdfFile);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _pickDirectory() async {
    // Ensure we have permission before picking
    final hasPermission = await PermissionService.hasStoragePermission();
    if (!hasPermission && mounted) {
      final granted = await PermissionService.showPermissionDialog(context);
      if (!granted) return;
    }

    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null && mounted) {
      final appState = context.read<AppState>();
      final pathsProvider = context.read<ScannedPathsProvider>();
      await pathsProvider.persistAfterPick(result);
      await appState.loadDirectory(result);
      _staggerController.reset();
      _staggerController.forward();
    }
  }

  void _openFile(PdfFile file) {
    final appState = context.read<AppState>();
    appState.selectFile(file);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ViewerScreen(file: file),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _deleteFile(PdfFile file) async {
    final fileOps = context.read<FileOperationsProvider>();
    final tagProvider = context.read<TagProvider>();
    final success = await fileOps.deleteFile(file);
    if (success) {
      // Clean up tag mapping for the deleted file.
      await tagProvider.forgetFile(file.path);
    }
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${file.displayName} deleted'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _shareFile(PdfFile file) async {
    await context.read<FileOperationsProvider>().shareFile(file.path);
  }

  Future<void> _encryptFile(PdfFile file) async {
    final encryption = context.read<EncryptionProvider>();
    if (!encryption.hasPassphrase) {
      final set = await showPassphraseDialog(context);
      if (!set || !mounted) return;
    }
    final fileOps = context.read<FileOperationsProvider>();
    final result = await fileOps.encryptFile(file);
    if (mounted && result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${file.displayName} encrypted'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _tagFile(PdfFile file) async {
    await showTagPickerDialog(context, filePath: file.path);
  }

  /// Apply tag filter and search together. AppState handles search + sort;
  /// the tag filter is applied on top in this widget.
  List<PdfFile> _filteredFiles(AppState appState, TagProvider tagProvider) {
    final files = appState.files;
    final activeTagId = tagProvider.activeFilterTagId;
    if (activeTagId == null) return files;
    return files
        .where((f) => tagProvider.fileHasTag(f.path, activeTagId))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final tagProvider = context.watch<TagProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search PDFs...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                onChanged: (q) => context.read<SortSearchProvider>().setSearchQuery(q),
              )
            : Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Feya PDF'),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded, size: 20),
            tooltip: _showSearch ? 'Close search' : 'Search',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  context.read<SortSearchProvider>().setSearchQuery('');
                }
              });
            },
          ),
          PopupMenuButton<SortBy>(
            icon: const Icon(Icons.sort_rounded, size: 20),
            tooltip: 'Sort',
            onSelected: (sortBy) {
              final sortSearch = context.read<SortSearchProvider>();
              if (sortSearch.sortBy == sortBy) {
                sortSearch.sortOrder = sortSearch.sortOrder == SortOrder.asc
                    ? SortOrder.desc
                    : SortOrder.asc;
              } else {
                sortSearch.sortBy = sortBy;
                sortSearch.sortOrder = SortOrder.desc;
              }
            },
            itemBuilder: (_) => [
              _sortItem(SortBy.name, Icons.sort_by_alpha_rounded, 'Name', context.read<SortSearchProvider>()),
              _sortItem(SortBy.modified, Icons.access_time_rounded, 'Date', context.read<SortSearchProvider>()),
              _sortItem(SortBy.size, Icons.data_usage_rounded, 'Size', context.read<SortSearchProvider>()),
            ],
          ),
          IconButton(
            icon: Icon(
              tagProvider.hasTags
                  ? Icons.label_rounded
                  : Icons.label_outline_rounded,
              size: 20,
            ),
            tooltip: 'Tags',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TagsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, size: 20),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: _buildBody(appState, context.read<SortSearchProvider>(), tagProvider, colorScheme),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickDirectory,
        tooltip: 'Open folder',
        child: const Icon(Icons.folder_open_rounded),
      ),
    );
  }

  Widget _buildBody(
    AppState appState,
    SortSearchProvider sortSearch,
    TagProvider tagProvider,
    ColorScheme colorScheme,
  ) {
    if (appState.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Scanning for PDFs...',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    if (appState.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                appState.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _pickDirectory,
                child: const Text('Pick a folder'),
              ),
            ],
          ),
        ),
      );
    }

    if (!appState.hasFiles) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 64,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No PDFs found',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Open a folder to scan for PDF files',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _pickDirectory,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Open folder'),
              ),
            ],
          ),
        ),
      );
    }

    final files = _filteredFiles(appState, tagProvider);
    return RefreshIndicator(
      onRefresh: () async {
        await appState.refresh();
        _staggerController.reset();
        _staggerController.forward();
      },
      child: Column(
        children: [
          // Tag filter bar — only when we have any tags to filter by.
          if (tagProvider.hasTags)
            _TagFilterBar(
              tagProvider: tagProvider,
              colorScheme: colorScheme,
            ),
          const SecureFolderCard(),
          Expanded(
            child: files.isEmpty
                ? _emptyFilterState(tagProvider, colorScheme)
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 88),
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return AnimatedBuilder(
                        animation: _staggerController,
                        builder: (context, child) {
                          final delay = (index * 0.03).clamp(0.0, 1.0);
                          final progress = (_staggerController.value - delay)
                              .clamp(0.0, 1.0);
                          return Opacity(
                            opacity: progress,
                            child: Transform.translate(
                              offset: Offset(0, 12 * (1 - progress)),
                              child: child,
                            ),
                          );
                        },
                        child: _buildFileTile(file, appState, tagProvider),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyFilterState(TagProvider tagProvider, ColorScheme colorScheme) {
    final activeTag = tagProvider.activeFilterTag;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_off_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No files tagged "${activeTag?.name ?? ""}"',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => tagProvider.clearFilter(),
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: const Text('Clear filter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileTile(
    PdfFile file,
    AppState appState,
    TagProvider tagProvider,
  ) {
    // Decorate the file with its current tag IDs from the provider.
    final tagsForFile = tagProvider.getResolvedTagsForFile(file.path);
    final decorated = file.copyWith(
      tagIds: tagsForFile.map((t) => t.id).toList(growable: false),
    );

    return Stack(
      children: [
        FileListTile(
          file: decorated,
          tags: tagsForFile,
          isSelected: appState.selectedFile?.path == file.path,
          onTap: () => _openFile(decorated),
          onDelete: () => _deleteFile(decorated),
          onShare: () => _shareFile(decorated),
          onEncrypt: file.isEncrypted ? null : () => _encryptFile(decorated),
          onTag: () => _tagFile(decorated),
        ),
        if (file.isEncrypted)
          Positioned(
            right: 24,
            top: 12,
            child: EncryptionBadge(),
          ),
      ],
    );
  }

  PopupMenuItem<SortBy> _sortItem(
    SortBy value,
    IconData icon,
    String label,
    SortSearchProvider sortSearch,
  ) {
    final isActive = sortSearch.sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isActive ? Theme.of(context).colorScheme.primary : null),
          const SizedBox(width: 12),
          Text(label),
          if (isActive) ...[
            const Spacer(),
            Icon(
              sortSearch.sortOrder == SortOrder.asc
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }
}

/// Horizontal scrollable row of tag filter chips, shown above the file list
/// when the user has at least one tag. Includes an "All" chip to clear.
class _TagFilterBar extends StatelessWidget {
  final TagProvider tagProvider;
  final ColorScheme colorScheme;

  const _TagFilterBar({
    required this.tagProvider,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final tags = tagProvider.tags;
    final activeId = tagProvider.activeFilterTagId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: tags.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            if (i == 0) {
              final selected = activeId == null;
              return _AllChip(
                selected: selected,
                onTap: () => tagProvider.clearFilter(),
                isDark: isDark,
              );
            }
            final tag = tags[i - 1];
            return TagChip(
              tag: tag,
              selected: activeId == tag.id,
              compact: true,
              onTap: () => tagProvider.setActiveFilter(
                activeId == tag.id ? null : tag.id,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AllChip extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;
  const _AllChip({
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
    final bg = selected
        ? primary
        : (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04));
    final fg = selected ? Colors.white : colorScheme.onSurfaceVariant;
    return Material(
      color: bg,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? primary
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected
                    ? Icons.check_rounded
                    : Icons.apps_rounded,
                size: 14,
                color: fg,
              ),
              const SizedBox(width: 6),
              Text(
                'All',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
