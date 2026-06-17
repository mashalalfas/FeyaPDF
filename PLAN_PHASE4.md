# Phase 4 — Proposal

## Current State Assessment

FeyaPDF v1.1 is a mature, polished PDF reader with:

- ✅ PDF viewer (pdfrx) — scroll, zoom, dark reading, thumbnails, search
- ✅ E2E encryption (AES-256-GCM) — passphrase, auto-encrypt, .pdf.enc format
- ✅ Secure folder — dedicated encrypted directory with import/export
- ✅ Tag system — 8-color palette, filter bar, management screen
- ✅ Text highlights — persistent, rendered on-page, panel with page nav
- ✅ In-document search — PdfTextSearcher, match navigation, highlights
- ✅ App lock — PIN setup, biometric unlock, lock gate screen
- ✅ Recent files — last 5 tracked, persisted to JSON
- ✅ File management — sort by name/date/size, search, long-press context menu
- ✅ "Open with" intent handler, SVG preview, share, theme, profile

## What's Missing

Despite strong foundations, several high-value features common to mature reading apps are absent:

1. **Bookmarks** — no lightweight page-marking mechanism (only text highlights exist)
2. **Reading progress visualization** — last-read position is tracked but never shown to the user
3. **Favorites / pinned files** — no way to prioritize important files in a growing library
4. **Batch operations** — users can only act on one file at a time
5. **Backup & restore** — tags, highlights, settings, and bookmarks are all local-only with no export

---

## Proposal — 5 Features for Phase 4

### 1. Bookmarks

**Value prop:** Readers need a quick way to mark and revisit important pages without selecting text — a lightweight, one-tap page bookmarking mechanism.

**Implementation approach:** New `Bookmark` model (pageNumber + label + filePath + timestamp), new `BookmarkProvider` backed by `BookmarkService` (SharedPreferences), bookmark button in viewer AppBar, and a collapsible bookmark panel (similar layout to `HighlightsPanel`) with tap-to-navigate and long-press-to-rename.

### 2. Reading progress indicators

**Value prop:** Users can instantly see how much of a PDF they've read directly in the file list, turning the library into a progress dashboard.

**Implementation approach:** Extend the existing last-read-position persistence (already in `SharedPreferences`) to also store total page count per file on first open; add a linear progress bar to `FileListTile` below the file metadata, and optionally show a percentage label in the viewer's page counter area.

### 3. Favorites / pinned files

**Value prop:** Give users a zero-friction way to surface their most important PDFs to the top of the file list without creating tags or folders.

**Implementation approach:** Add a `isFavorite` boolean to `PdfFile` (stored in a new key-value map in `SharedPreferences` by file path), a star/Heart toggle on each `FileListTile` (long-press or dedicated icon), and a "Show favorites first" sort option in the existing sort/search bar.

### 4. Batch operations (multi-select mode)

**Value prop:** Power users can select multiple files at once to tag, encrypt, move to secure folder, share, or delete in bulk instead of one-at-a-time.

**Implementation approach:** New `SelectionProvider` tracks selected file paths; add a long-press-activated selection mode to the home screen (checkboxes on each `FileListTile`, AppBar switches to "X selected" with action buttons for tag/encrypt/delete/secure-move); modify `FileOperationsProvider` to accept lists of paths.

### 5. Backup & restore

**Value prop:** Users can export their reading state (tags, highlights, bookmarks, recent files, settings) as a portable JSON file and restore it on another device or after a reset.

**Implementation approach:** New `BackupService` that collects all serializable state from `TagService`, `HighlightService`, `BookmarkService`, `SettingsService`, and `RecentFilesProvider` into a single JSON blob; export via `share_plus` (file); import via `file_picker` with a confirmation dialog showing what will be restored.

---

## Ordering Rationale

| # | Feature | User Impact | Effort | Rationale |
|---|---------|-------------|--------|-----------|
| 1 | Bookmarks | 🔥🔥🔥🔥 | 1-2 days | Daily reader need; fills the biggest functional gap |
| 2 | Reading progress | 🔥🔥🔥 | 0.5-1 day | Data already exists; minimal effort for high visibility |
| 3 | Favorites | 🔥🔥🔥 | 0.5 day | Dead simple, noticeable improvement to library UX |
| 4 | Batch ops | 🔥🔥 | 2-3 days | Medium effort, high power-user value |
| 5 | Backup/restore | 🔥🔥 | 1-2 days | Important for data portability, less urgent for daily use |

## Dependencies & Blockers

- **None.** All 5 features build on existing infrastructure (SharedPreferences, Provider, existing screens/widgets).
- **Potential concern:** If bookmarks or progress data grows significantly, consider migrating from SharedPreferences to a local SQLite database (e.g., `drift` or `sqflite`) for Phase 5 — but not needed for Phase 4 scope.
- **No new packages required** for any of the 5 features (use existing `share_plus`, `file_picker`, `shared_preferences`, and `provider`).
