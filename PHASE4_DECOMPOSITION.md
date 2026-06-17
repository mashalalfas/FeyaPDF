# Phase 4 — Atomic Decomposition Plan

## Overview

Phase 4 adds 5 features to FeyaPDF: **Bookmarks**, **Reading Progress**, **Favorites**, **Batch Operations**, and **Backup/Restore**.

The plan decomposes these into **49 atomic work items**, each independently buildable by a Kimi K2.6 soldier in one session. Items are ordered so no piece depends on a later piece. Tests are specified for each item.

### Architecture Principles Followed
- New models go in `lib/models/` (immutable, JSON-serializable)
- New services go in `lib/services/` (SharedPreferences-backed persistence)
- New providers go in `lib/providers/` (ChangeNotifier with service injection)
- New widgets go in `lib/widgets/` (stateless unless stateful needed)
- Provider registration happens in `lib/main.dart`
- Cross-provider wiring uses `addPostFrameCallback` in `main.dart`

### Build Order Guidance
- Items within a feature are ordered sequential (each depends on previous)
- Feature 1 (Bookmarks) should be built first — no dependencies on other features
- Feature 3 (Favorites) is simplest — can be built in parallel with Feature 1
- Feature 2 (Reading Progress) depends on total page count tracking — can start after Feature 1 items #1-#4
- Feature 4 (Batch Ops) depends on nothing — can start early
- Feature 5 (Backup/Restore) depends on all previous features being complete (it collects data from them)

### Dependency Graph (Visual)
```
F1.1  ←  F1.2  ←  F1.3  ←  F1.4  ←  F1.5  ←  F1.6  ←  F1.7  ←  F1.8
                                                                            ↘
F3.1  ←  F3.2  ←  F3.3  ←  F3.4  ←  F3.5  ←  F3.6                         F5.1 … F5.10
                                                                          ↗
F2.1  ←  F2.2  ←  F2.3  ←  F2.4  ←  F2.5
```
Feature 4 (Batch Ops — F4.1–F4.10) is fully independent.

---

## Feature 1: Bookmarks (18 items)

### Model & Service Layer

**[#01] Feature: Create Bookmark model with JSON serialization**
- **File:** `lib/models/bookmark.dart` (create)
- **Change:** Add `Bookmark` class with fields: `id`, `filePath`, `pageNumber`, `label` (nullable), `createdAt`. Include `toJson()`, `fromJson()`, `copyWith()`, `==`/`hashCode`. Follow exact pattern of `HighlightData`.
- **Deps:** None
- **Test:** Unit test: create Bookmark, serialize to JSON, deserialize, verify fields match.

**[#02] Feature: Create BookmarkService (SharedPreferences-backed CRUD)**
- **File:** `lib/services/bookmark_service.dart` (create)
- **Change:** Add `BookmarkService` class taking `SharedPreferences`. Store bookmarks as JSON map keyed by `'feya_pdf_bookmarks'` — same layout as `HighlightService`: `{ filePath → [BookmarkJSON, ...] }`. Methods: `loadAll()`, `loadForFile(String)`, `saveForFile(String, List<Bookmark>)`, `deleteBookmark(String id)`.
- **Deps:** #01
- **Test:** Unit test: add two bookmarks for same file, verify loadForFile returns both, delete one, verify counts.

**[#03] Feature: Create BookmarkProvider (ChangeNotifier with CRUD)**
- **File:** `lib/providers/bookmark_provider.dart` (create)
- **Change:** Add `BookmarkProvider` taking `BookmarkService`. Follow exact pattern of `HighlightProvider`. Fields: `_bookmarks`, `_fileBookmarks`, `_currentFilePath`, `_showPanel`. Methods: `openFile(String)`, `closeFile()`, `addBookmark(Bookmark)`, `removeBookmark(String id)`, `togglePanel()`, `setShowPanel(bool)`, `renameBookmark(String id, String newLabel)`.
- **Deps:** #01, #02
- **Test:** Unit test: open file, add bookmark, verify fileBookmarks count is 1, close file, verify fileBookmarks is empty.

**[#04] Feature: Register BookmarkProvider in main.dart**
- **File:** `lib/main.dart` (edit)
- **Change:** Import `BookmarkProvider` and `BookmarkService`. Add `ChangeNotifierProvider(create: (_) => BookmarkProvider(BookmarkService(prefs)))` to the `MultiProvider` providers list, after `HighlightProvider`.
- **Deps:** #02, #03
- **Test:** Visual: app launches without crash, BookmarkProvider is accessible via `context.read<BookmarkProvider>()`.

### Viewer UI (Bookmark Button & Panel)

**[#05] Feature: Add bookmark toggle button to viewer AppBar**
- **File:** `lib/screens/viewer_screen.dart` (edit)
- **Change:** Add a bookmark IconButton between the highlights-panel button and the save button. Icon shows `Icons.bookmark_rounded` (filled) when the current page is bookmarked, `Icons.bookmark_border_rounded` (outlined) otherwise. On press: if current page already bookmarked → remove bookmark; else → add bookmark with label=null. Use `context.read<BookmarkProvider>()`.
- **Deps:** #03, #04
- **Test:** Widget test: render ViewerScreen with mock providers, tap bookmark button, verify bookmark added for current page.

**[#06] Feature: Create BookmarksPanel widget (collapsible panel listing bookmarks)**
- **File:** `lib/widgets/bookmarks_panel.dart` (create)
- **Change:** Create `BookmarksPanel` widget following exact pattern of `HighlightsPanel`. Shows bookmarks grouped by page. Each bookmark tile shows: page number, label (or "Page X" if null), created time. Tap → navigate to page via callback. Swipe/button to delete. Has close button. Follow same layout (header bar, ListView body).
- **Deps:** #01, #03
- **Test:** Widget test: render BookmarksPanel with mock BookmarkProvider containing 2 bookmarks, verify both are displayed with page numbers.

**[#07] Feature: Show BookmarksPanel in viewer when togglePanel is active**
- **File:** `lib/screens/viewer_screen.dart` (edit)
- **Change:** Add `context.watch<BookmarkProvider>().showPanel` animated block after the HighlightsPanel block. Render `BookmarksPanel` with `onNavigateToPage` callback calling `_pdfController?.goToPage(pageNumber: page)` and `onClose` calling `context.read<BookmarkProvider>().setShowPanel(false)`.
- **Deps:** #05, #06
- **Test:** Visual: open viewer, tap bookmark button, verify bookmarks panel appears. Tap close, verify panel disappears.

**[#08] Feature: Add bookmark indicator to page indicator / page counter area**
- **File:** `lib/screens/viewer_screen.dart` (edit)
- **Change:** In `_buildPageIndicator`, add a small bookmark icon next to the page counter when current page is bookmarked. Query `context.watch<BookmarkProvider>().fileBookmarks.any((b) => b.pageNumber == _currentPage)`. Show a small filled bookmark icon (Icons.bookmark_rounded, size 14, primary color).
- **Deps:** #03, #05
- **Test:** Visual: navigate to a bookmarked page, verify bookmark icon appears in bottom bar.

### Rename & Context Menu

**[#09] Feature: Add long-press rename to bookmark tile in BookmarksPanel**
- **File:** `lib/widgets/bookmarks_panel.dart` (edit)
- **Change:** Add `onLongPress` to bookmark ListTile that shows a rename dialog (inline TextField or AlertDialog). On submit, call `context.read<BookmarkProvider>().renameBookmark(id, newLabel)`.
- **Deps:** #06
- **Test:** Widget test: render bookmark tile, long-press, type new label, verify label updates.

**[#10] Feature: Implement renameBookmark in BookmarkProvider**
- **File:** `lib/providers/bookmark_provider.dart` (edit)
- **Change:** Add `renameBookmark(String id, String newLabel)` method. Find bookmark by ID, create copy with new label, update `_bookmarks` list, persist via `_service.saveForFile()`, notify.
- **Deps:** #03, #09
- **Test:** Unit test: add bookmark, rename it, verify label changed and persistence called.

### Long-press Context Menu on Bookmarked Page

**[#11] Feature: Add "Bookmark this page" context menu to viewer bottom bar**
- **File:** `lib/screens/viewer_screen.dart` (edit)
- **Change:** Replace the current page-counter GestureDetector with a PopupMenuButton variant. Add a menu item "Bookmark this page" (with bookmark icon) that toggles the bookmark for current page. Only show when page is not already bookmarked.
- **Deps:** #03, #05
- **Test:** Widget test: long-press page counter, verify menu appears with bookmark option.

### Library Integration

**[#12] Feature: Show bookmark count on FileListTile**
- **File:** `lib/widgets/file_list_tile.dart` (edit)
- **Change:** Add optional `int? bookmarkCount` parameter. When > 0, show a small bookmark icon with count below the metadata row (next to or below tag row). Display as `Icons.bookmark_rounded` (small, 11px) + "N" text.
- **Deps:** #01 (Bookmark model)
- **Test:** Widget test: render FileListTile with bookmarkCount=3, verify icon and "3" are displayed.

**[#13] Feature: Pass bookmark counts to FileListTile in HomeScreen**
- **File:** `lib/screens/home_screen.dart` (edit)
- **Change:** In `_buildFileTile`, read `context.watch<BookmarkProvider>().allHighlights` → filter by file path → count. Pass count as `bookmarkCount` to `FileListTile`. (Use `context.watch` or check in builder).
- **Deps:** #03, #12
- **Test:** Visual: open file list, verify bookmarked files show bookmark count.

### Migration & Cleanup

**[#14] Feature: Verify bookmark data integrity on file rename/deletion**
- **File:** `lib/providers/bookmark_provider.dart` (edit)
- **Change:** Add `forgetFile(String filePath)` method that removes all bookmarks for a given file path. Add `renameFile(String oldPath, String newPath)` that updates all bookmark file paths.
- **Deps:** #03
- **Test:** Unit test: add bookmarks for file A, call forgetFile(A), verify bookmarks for A are gone.

**[#15] Feature: Call bookmarkProvider.forgetFile when deleting files**
- **File:** `lib/screens/home_screen.dart` (edit)
- **Change:** In `_deleteFile` method, after tag cleanup, also call `context.read<BookmarkProvider>().forgetFile(file.path)`.
- **Deps:** #14
- **Test:** Visual: bookmark a file, delete it, verify bookmark doesn't reappear on refresh.

### Is Page Bookmarked Helper

**[#16] Feature: Add `isPageBookmarked(int pageNumber)` to BookmarkProvider**
- **File:** `lib/providers/bookmark_provider.dart` (edit)
- **Change:** Add convenience getter `isPageBookmarked(int pageNumber)` returning `_fileBookmarks.any((b) => b.pageNumber == pageNumber)`. Used by the bookmark icon in the viewer.
- **Deps:** #03
- **Test:** Unit test: add bookmark for page 5, verify `isPageBookmarked(5)` returns true, `isPageBookmarked(3)` returns false.

### Test Suite

**[#17] Feature: Write comprehensive BookmarkService test**
- **File:** `test/bookmark_service_test.dart` (create)
- **Change:** Unit tests for BookmarkService: CRUD operations, empty state, malformed JSON resilience, multi-file isolation.
- **Deps:** #02
- **Test:** N/A (this IS the test)

**[#18] Feature: Write comprehensive BookmarkProvider test**
- **File:** `test/bookmark_provider_test.dart` (create)
- **Change:** Unit tests for BookmarkProvider: openFile/closeFile lifecycle, add/remove/rename, forgetFile, isPageBookmarked, panel toggle state.
- **Deps:** #03, #17
- **Test:** N/A (this IS the test)

---

## Feature 2: Reading Progress Indicators (8 items)

### Data Layer

**[#19] Feature: Add `totalPages` field to last-read-position persistence**
- **File:** `lib/services/settings_service.dart` (edit)
- **Change:** Add `lastReadPositions` extended to store `{ path: { page: int, total: int } }` instead of just `{ path: int }`. Add `setLastReadPage(String path, int page, int totalPages)` (new signature). Add `getLastReadProgress(String path)` returning `(int page, int totalPages)?`. Keep backward compat: read old format `{ path: int }` and migrate on write.
- **Deps:** None (isolated service change)
- **Test:** Unit test: set progress for file with 100 pages, page 42, verify correct page and total returned.

**[#20] Feature: Update SettingsProvider to expose total pages**
- **File:** `lib/providers/settings_provider.dart` (edit)
- **Change:** Add `getLastReadProgress(String path)` returning `(int page, int totalPages)?`. Update `setLastReadPage` to accept optional `totalPages` parameter (default null keeps existing). Add `setLastReadProgress(String path, int page, int totalPages)`.
- **Deps:** #19
- **Test:** Unit test: set progress, get progress, verify both page and total stored.

**[#21] Feature: Capture total page count when viewer loads PDF**
- **File:** `lib/screens/viewer_screen.dart` (edit)
- **Change:** In `_onViewerReady` callback, after `_totalPages` is set, call `context.read<SettingsProvider>().setLastReadProgress(widget.file.path, _currentPage, _totalPages)` to persist total page count. Also update `_onPageChanged` to pass total pages.
- **Deps:** #20
- **Test:** Visual: open PDF, navigate pages, close, verify progress data persisted.

### File List UI

**[#22] Feature: Add linear progress bar to FileListTile**
- **File:** `lib/widgets/file_list_tile.dart` (edit)
- **Change:** Add optional `double? progressValue` parameter (0.0–1.0). When non-null, show a thin LinearProgressIndicator below the metadata row (or tag row). Use `colorScheme.primary` with `trackColor` at 0.08 opacity, height 3px, rounded corners.
- **Deps:** None (widget change)
- **Test:** Widget test: render FileListTile with progressValue=0.42, verify progress bar visible and width matches.

**[#23] Feature: Pass reading progress to FileListTile in HomeScreen**
- **File:** `lib/screens/home_screen.dart` (edit)
- **Change:** In `_buildFileTile`, read `context.read<SettingsProvider>().getLastReadProgress(file.path)` to get `(page, total)`. Calculate `progress = page / total` when total > 0. Pass to `FileListTile` as `progressValue`.
- **Deps:** #20, #22
- **Test:** Visual: open partially-read PDF, return to file list, verify progress bar visible on that file.

### Viewer UI

**[#24] Feature: Show percentage label in page counter area**
- **File:** `lib/screens/viewer_screen.dart` (edit)
- **Change:** In `_buildPageIndicator`, add a small percentage text next to the page counter, e.g. "42 / 100 · 42%". Calculate as `(_currentPage / _totalPages * 100).round()`. Show in a slightly muted color to distinguish from the main counter.
- **Deps:** None (already have `_currentPage` and `_totalPages`)
- **Test:** Widget test: set page 42 of 100, verify "42%" appears in bottom bar.

### Test Suite

**[#25] Feature: Write reading progress unit tests**
- **File:** `test/reading_progress_test.dart` (create)
- **Change:** Tests for SettingsProvider progress getters/setters, migration from old format, edge cases (total=0, page=0).
- **Deps:** #19, #20
- **Test:** N/A (this IS the test)

---

## Feature 3: Favorites / Pinned Files (7 items)

### Data Layer

**[#26] Feature: Add file favorite map to SettingsService**
- **File:** `lib/services/settings_service.dart` (edit)
- **Change:** Add `_kFavorites` key `'mely_pdf_favorites'`. Methods: `getFavorites()` returning `Set<String>` (paths), `setFavorite(String path, bool value)`, `isFavorite(String path)`. Store as JSON string list or SharedPreferences string set.
- **Deps:** None
- **Test:** Unit test: favorite a path, verify isFavorite true, unfavorite, verify false.

**[#27] Feature: Create FavoritesProvider (ChangeNotifier)**
- **File:** `lib/providers/favorites_provider.dart` (create)
- **Change:** Create `FavoritesProvider` wrapping `SettingsService` favorites methods. Extends `ChangeNotifier`. Fields: `_favoritePaths` (Set<String>). Methods: `isFavorite(String path)`, `toggleFavorite(String path)`, `getFavorites()`. Loads on init. Fires notifyListeners on toggle.
- **Deps:** #26
- **Test:** Unit test: toggle favorite on path A, verify isFavorite true, toggle again, verify false.

**[#28] Feature: Register FavoritesProvider in main.dart**
- **File:** `lib/main.dart` (edit)
- **Change:** Import `FavoritesProvider`. Add `ChangeNotifierProvider(create: (_) => FavoritesProvider(context.read<SettingsProvider>()))` to providers list.
- **Deps:** #27
- **Test:** Visual: app launches without crash, FavoritesProvider accessible.

### UI

**[#29] Feature: Add star/favorite toggle icon to FileListTile**
- **File:** `lib/widgets/file_list_tile.dart` (edit)
- **Change:** Add optional `bool isFavorite` and `VoidCallback? onToggleFavorite` parameters. When `onToggleFavorite` is provided, show a star icon (`Icons.star_rounded` filled or `Icons.star_border_rounded` outline) in the top-right of the tile, tappable independently from the main row tap. Position it next to the chevron or as an overlay.
- **Deps:** None
- **Test:** Widget test: render tile with isFavorite=true, verify filled star visible. Tap star, verify callback invoked.

**[#30] Feature: Wire favorite toggle in HomeScreen**
- **File:** `lib/screens/home_screen.dart` (edit)
- **Change:** In `_buildFileTile`, read `context.watch<FavoritesProvider>().isFavorite(file.path)`. Pass `isFavorite` and `onToggleFavorite: () => context.read<FavoritesProvider>().toggleFavorite(file.path)` to `FileListTile`.
- **Deps:** #28, #29
- **Test:** Visual: tap star on file, verify it fills. Tap again, verify it unfills.

**[#31] Feature: Add "Favorites first" sort option to SortSearchProvider**
- **File:** `lib/providers/sort_search_provider.dart` (edit)
- **Change:** Add `bool showFavoritesFirst = false` field. Add `toggleFavoritesFirst()` method. Update `apply()` method: when `showFavoritesFirst` is true, sort so favorited files appear first (within the existing sort order). The provider needs access to favorite paths — add a `Set<String> Function()` setter `favoritesChecker` or pass through a callback.
- **Deps:** #27
- **Test:** Unit test: pass 3 files (one favorited), enable favoritesFirst, verify favorite file is first in result list.

**[#32] Feature: Add "Favorites first" toggle to sort menu in HomeScreen**
- **File:** `lib/screens/home_screen.dart` (edit)
- **Change:** Add a `.PopupMenuDivider()` and a `PopupMenuItem` with a CheckedPopupMenuItem or row with star icon + "Favorites first" + checkbox. Toggle `sortSearch.toggleFavoritesFirst()` on tap.
- **Deps:** #31
- **Test:** Visual: tap sort, see "Favorites first" option, toggle it, verify favorite files appear at top.

---

## Feature 4: Batch Operations (10 items)

### Data Layer

**[#33] Feature: Create SelectionProvider (multi-select state)**
- **File:** `lib/providers/selection_provider.dart` (create)
- **Change:** Create `SelectionProvider extends ChangeNotifier`. Fields: `_selectedPaths` (Set<String>), `_isSelectionMode` (bool). Methods: `enterSelectionMode()`, `exitSelectionMode()`, `toggleSelection(String path)`, `isSelected(String path)`, `selectAll(List<String> paths)`, `clearSelection()`, `get selectedPaths`, `get isSelectionMode`, `get selectedCount`. Clear selection when exiting mode.
- **Deps:** None
- **Test:** Unit test: enter selection mode, select 2 files, verify selectedCount=2, exit mode, verify isSelectionMode=false.

**[#34] Feature: Register SelectionProvider in main.dart**
- **File:** `lib/main.dart` (edit)
- **Change:** Import `SelectionProvider`. Add `ChangeNotifierProvider(create: (_) => SelectionProvider())` to providers list.
- **Deps:** #33
- **Test:** Visual: app launches without crash.

### UI — File List Selection Mode

**[#35] Feature: Add selection checkbox to FileListTile**
- **File:** `lib/widgets/file_list_tile.dart` (edit)
- **Change:** Add optional `bool isSelectionMode` and `bool isSelected` and `VoidCallback? onSelectToggle` parameters. When `isSelectionMode` is true, replace the leading file icon with a `Checkbox`. The chevron is hidden. The main tap area toggles selection instead of opening the file.
- **Deps:** None
- **Test:** Widget test: enable selection mode, verify checkbox visible. Tap, verify onSelectToggle called.

**[#36] Feature: Wire selection mode in HomeScreen**
- **File:** `lib/screens/home_screen.dart` (edit)
- **Change:** Read `context.watch<SelectionProvider>()`. Pass `isSelectionMode`, `isSelected`, `onSelectToggle` to `FileListTile`. On long-press of any file tile, call `selectionProvider.enterSelectionMode()` and select that file. When selection mode is active, tapping a file toggles its selection.
- **Deps:** #34, #35
- **Test:** Visual: long-press file, verify checkbox appears on all tiles. Tap another file, verify checked. Tap again, unchecked.

**[#37] Feature: Modify AppBar in selection mode (show count, exit button)**
- **File:** `lib/screens/home_screen.dart` (edit)
- **Change:** When `selectionProvider.isSelectionMode`, change AppBar title to "X selected" and leading to a close button (Icons.close_rounded). Add action buttons after the title for: Tag, Encrypt, Delete, Share (each as compact IconButton). These call batch operation methods (stubs for now, wired in #39–#40).
- **Deps:** #34
- **Test:** Visual: enter selection mode, verify AppBar changes to show count and actions.

### Batch Operations Logic

**[#38] Feature: Add batch operation methods to FileOperationsProvider**
- **File:** `lib/providers/file_operations_provider.dart` (edit)
- **Change:** Add methods: `Future<int> batchDelete(List<String> paths)` (deletes each, returns success count), `Future<List<String>> batchEncrypt(List<String> paths)` (encrypts each, returns list of encrypted paths), `batchShare(List<String> paths)` (shares multiple via share_plus XFiles). Each method calls the existing single-file operation for each path.
- **Deps:** None (uses existing single-file ops)
- **Test:** Unit test: batchDelete 3 paths (2 exist, 1 doesn't), verify success count = 2.

**[#39] Feature: Wire batch delete from selection mode AppBar**
- **File:** `lib/screens/home_screen.dart` (edit)
- **Change:** Wire the batch delete button in selection mode AppBar. On press: show confirmation dialog "[N] files will be permanently deleted". On confirm: call `fileOps.batchDelete(selectedPaths)`, then `selectionProvider.exitSelectionMode()`, then refresh file list.
- **Deps:** #37, #38
- **Test:** Visual: select files, tap delete, confirm dialog, verify files deleted and selection mode exits.

**[#40] Feature: Wire batch share from selection mode AppBar**
- **File:** `lib/screens/home_screen.dart` (edit)
- **Change:** Wire batch share button. On press: call `fileOps.batchShare(selectedPaths)`, then `selectionProvider.exitSelectionMode()`.
- **Deps:** #37, #38
- **Test:** Visual: select files, tap share, verify share sheet opens with multiple files.

**[#41] Feature: Add batch tag operation from selection mode**
- **File:** `lib/screens/home_screen.dart` (edit)
- **Change:** Wire batch tag button. On press: open `showTagPickerDialog` (or a multi-file variant). When tags are applied, call `tagProvider.setFileTags(path, tagIds)` for each selected path. Then exit selection mode.
- **Deps:** #37 (uses existing `showTagPickerDialog` pattern)
- **Test:** Visual: select files, tap tag, pick a tag, verify all selected files now have that tag.

**[#42] Feature: Add batch encrypt / secure-move from selection mode AppBar**
- **File:** `lib/screens/home_screen.dart` (edit)
- **Change:** Add batch encrypt button (lock icon, shown only when passphrase is set). On press: encrypt each selected file via `fileOps.batchEncrypt()`. Show snackbar with success count. Also add a "Move to Secure Folder" option in an overflow menu if selectionProvider.isSelectionMode.
- **Deps:** #37, #38
- **Test:** Visual: select unencrypted files, tap encrypt, verify they become .pdf.enc.

---

## Feature 5: Backup & Restore (10 items)

### Data Collection Service

**[#43] Feature: Create BackupService (collects all state)**
- **File:** `lib/services/backup_service.dart` (create)
- **Change:** Create `BackupService` with methods:
  - `Future<String> exportAll({required TagService, required HighlightService, required BookmarkService, required SettingsService, required RecentFilesProvider})` — collects tags, file→tag map, highlights, bookmarks, settings (theme mode, autoEncrypt, continuousScroll, darkReadingMode, showThumbnails, appLockEnabled, userProfile, userProfile), recent file paths, favorites, last-read-progress into a single JSON blob.
  - `Future<bool> importFromJson(String json, {required TagService, required HighlightService, required BookmarkService, required SettingsService, required RecentFilesProvider})` — parses JSON, restores each data source with confirmation callbacks.
- **Deps:** All prior features complete (needs all service types)
- **Test:** Unit test: export with some sample data, verify JSON structure has all expected keys.

**[#44] Feature: Create BackupProvider (ChangeNotifier)**
- **File:** `lib/providers/backup_provider.dart` (create)
- **Change:** `BackupProvider extends ChangeNotifier`. Fields: `bool isExporting`, `bool isImporting`, `String? lastExportPath`. Methods: `exportBackup(context)`, `importBackup(context)`. Uses `BackupService` internally.
- **Deps:** #43
- **Test:** Unit test: export, verify lastExportPath is set. Mock import, verify success.

**[#45] Feature: Register BackupProvider in main.dart**
- **File:** `lib/main.dart` (edit)
- **Change:** Import `BackupProvider` and `BackupService`. Add provider. Requires passing all service instances — use `ProxyProvider` or create in `main()` before `runApp` and pass to both the provider and services.
- **Deps:** #44
- **Test:** Visual: app launches without crash.

### Export UI

**[#46] Feature: Add "Export backup" button to SettingsScreen**
- **File:** `lib/screens/settings_screen.dart` (edit)
- **Change:** Add a `_SectionHeader('Backup & Restore')` section with two ListTiles: "Export backup" (icon: `Icons.backup_rounded`) and "Import backup" (icon: `Icons.restore_rounded`). Export tile calls `backupProvider.exportBackup(context)` which uses `share_plus` to share the JSON file. Import tile calls `backupProvider.importBackup(context)` which uses `file_picker` to pick a .json file.
- **Deps:** #45
- **Test:** Visual: settings screen shows backup section. Tap export → share sheet opens with .json file.

**[#47] Feature: Implement exportAll in BackupService (data collection)**
- **File:** `lib/services/backup_service.dart` (edit)
- **Change:** Implement the `exportAll` method body. Collect:
  - `version: 1`, `exportedAt: ISO8601`
  - tags, fileTagMap, highlights, bookmarks, settings (all key-value pairs from SettingsService except lastReadPositions — include them separately), recentFiles, favorites, lastReadPositions.
  - Wrap in `{ metadata: {...}, data: { tags: [...], ... } }` structure.
- **Deps:** #43
- **Test:** Unit test: populate each service with sample data, export, verify JSON has all sections.

**[#48] Feature: Implement importFromJson in BackupService**
- **File:** `lib/services/backup_service.dart` (edit)
- **Change:** Implement `importFromJson` method. Parse JSON, validate metadata.version. For each section, call the corresponding service's save method. Return `true` on success, `false` on schema error. Log what was restored for confirmation dialog.
- **Deps:** #43, #47
- **Test:** Unit test: export data, clear services, import same data, verify all values restored.

### Restoration Flow & Test

**[#49] Feature: Add confirmation dialog before import**
- **File:** `lib/providers/backup_provider.dart` (edit)
- **Change:** Before calling `importFromJson`, show an AlertDialog listing what will be restored (e.g., "• 3 tags\n• 5 highlights\n• 2 bookmarks\n…"). User confirms or cancels. Only import on confirm. Wires through `context` for dialog.
- **Deps:** #44, #48
- **Test:** Widget test: mock file picker returning valid JSON, verify confirmation dialog contents match summary.

---

## Summary

| Feature | Items | Files Created | Files Modified | Est. Effort |
|---------|-------|---------------|----------------|-------------|
| Bookmarks | 18 | 6 | 4 | 2-3 days |
| Reading Progress | 8 | 1 | 4 | 0.5-1 day |
| Favorites | 7 | 1 | 4 | 0.5 day |
| Batch Operations | 10 | 1 | 4 | 2-3 days |
| Backup & Restore | 10 | 3 | 2 | 1-2 days |
| **Total** | **53** | **12** | **18** | **~7-10 days** |

### Key Patterns to Follow

1. **New model → Service → Provider → main.dart registration** (for any new persistent data)
2. **Provider constructor takes service** — never create service inside provider
3. **Tests mirror service/provider naming**: `test/{name}_test.dart`
4. **All SharedPreferences keys prefixed with** `'feya_pdf_'` or `'mely_pdf_'` (legacy prefix)
5. **Widget-level state** (panels, dialogs) uses provider, not local state
6. **Cross-provider communication** uses `context.read<>()` in widgets, never direct provider-to-provider coupling
7. **`copyWith` pattern** for immutable model updates
8. **`notifyListeners()`** after every state change in providers

### Test Command
```bash
cd ~/Development/FeyaPDF && flutter test
```
Run after each soldier completes their item to verify nothing is broken.
