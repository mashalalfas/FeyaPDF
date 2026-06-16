# BUG REPORT 001 — Folder scanning silently fails for existing files

**Date:** 2026-06-15  
**Severity:** High — Silent failure, user-facing data loss  
**Reported:** "folder not read..for existing files.. silently failing in the background"

---

## Executive Summary

FeyaPDF has a **stack of silent failure points** in its folder-scanning pipeline. When any of them triggers, the user sees "No PDFs found" or receives no feedback at all — even though their PDF files exist and the folders are intact. There is no single root cause; **four independent bugs conspire to make failure invisible.**

---

## 1. Full Flow Trace (App Start → File Display)

```
main()
 └─ HomeScreen._loadInitialData()
     ├─ loadPersistedDir()           → returns last-used folder path
     ├─ loadScannedPaths()           → loads saved folder paths from SharedPreferences
     │
     ├── [Path A] persistedDir exists?
     │    └─ YES → appState.loadDirectory(persisted)
     │              ├─ isReadable(path)
     │              │   ├─ dir.exists()    → [SILENT POINT #4]
     │              │   └─ dir.list()      → [SILENT POINT #4]
     │              ├─ if readable → scanDirectoryRecursive(path)
     │              │   └─ Isolate.run()   → [SILENT POINTS #1, #3]
     │              │       ├─ existsSync()
     │              │       ├─ listSync()  → caught, debugPrint (INVISIBLE)
     │              │       └─ fromFileSystem → caught, debugPrint (INVISIBLE)
     │              └─ returns files or error
     │
     └── [Path B] scannedPaths.isNotEmpty?
          └─ YES → appState.loadAllDirectories(scannedPaths)
                    └─ for each path:
                         ├─ isReadable     → [SILENT POINT #4]
                         └─ scanDirectory  → [SILENT POINT #2] ← CRITICAL
                    └─ aggregate all files, display
```

---

## 2. Silent Failure Points (Every One in the Chain)

### 🔴 SILENT POINT #1 — `debugPrint` inside `Isolate.run()` (MOST INSIDIOUS)

**File:** `lib/services/file_service.dart`  
**Lines:** 23, 28, 55, 67

```dart
static Future<List<PdfFile>> scanDirectoryRecursive(String dirPath, ...) async {
  return Isolate.run(() {
    // ...
    } catch (e) {
      debugPrint('FileService: error listing directory ${entry.path}: $e'); // ← INVISIBLE
      continue;
    }
    // ...
    } catch (e) {
      debugPrint('FileService: error scanning ${entity.path}: $e');  // ← INVISIBLE
    }
```

**Why it's broken:** `debugPrint()` in Dart isolates does **not** write to the Flutter debug console, logcat, or any visible output. The messages are **completely lost**. This means every `catch` block inside the isolate silently discards its error — there is zero diagnostic trail when permission errors, filesystem exceptions, or any other failure occurs during scanning.

**Impact:** Even when the code "handles" errors properly (catching, logging, continuing), the logging itself is invisible. The developer cannot diagnose permission errors, corrupt file paths, or filesystem exceptions that occur during scanning. This turns every caught exception into a silent failure.

---

### 🔴 SILENT POINT #2 — `catch (_) {}` in `loadAllDirectories` (HIGHEST LIKELIHOOD)

**File:** `lib/providers/app_state.dart`  
**Line:** 113

```dart
Future<void> loadAllDirectories(List<String> paths) async {
    // ...
    final results = await Future.wait(
      paths.map((path) async {
        try {
          if (await FileService.isReadable(path)) {
            final dirFiles = _fileCache.containsKey(path)
                ? _fileCache[path]!
                : await FileService.scanDirectoryRecursive(path, maxDepth: 10);
            _fileCache[path] = List.unmodifiable(dirFiles);
            return dirFiles;
          }
        } catch (_) {}    // ← SWALLOWS EVERYTHING
        return <PdfFile>[];
      }),
    );
```

**Why it's broken:** This `catch (_) {}` swallows ALL exceptions — `FileSystemException` (permission denied), `IsolateSpawnException` (isolate crash), `FileSystemException` from `isReadable()`, and everything else. The function `isReadable()` itself can throw (it has a `catch (_)` but can still fail in unexpected ways), `scanDirectoryRecursive` can throw at the Future level (if the isolate crashes), and the `await` can fail. All are consumed with zero logging, zero user feedback, zero state change.

**Impact:** This is the #1 suspect for the reported bug. If a user has multiple scanned paths and NONE of them produce files (all fail due to permission, isolate issues, or filesystem errors), the aggregated `_files` is empty and the UI shows "No PDFs found" — with absolutely no indication that multiple directories were tried and ALL failed.

---

### 🟡 SILENT POINT #3 — `existsSync()` inside isolate returns `false` silently

**File:** `lib/services/file_service.dart`  
**Line:** 47

```dart
return Isolate.run(() {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return <PdfFile>[];  // ← NO LOGGING

  final pdfFiles = <PdfFile>[];
  // ...
```

**Why it's broken:** On Android 11+ with scoped storage, `Directory.existsSync()` can return `false` for paths that DO exist but to which the app lacks permission. This is NOT a FileSystemException — it's a silent boolean `false`. There is no logging, no error, nothing. The function returns an empty list as if the directory simply didn't exist.

**Impact:** If `isReadable()` (which runs on the main thread) succeeds but `existsSync()` (running in the isolate) fails — e.g., because the isolate's thread doesn't inherit the same filesystem access level — the scan silently produces zero files. The user sees "No PDFs found" even though the directory exists and contains PDFs.

---

### 🟡 SILENT POINT #4 — `isReadable()` catches all exceptions silently

**File:** `lib/services/file_service.dart`  
**Lines:** 126-135

```dart
static Future<bool> isReadable(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) return false;
      await for (final _ in dir.list(followLinks: false)) {
        return true;
      }
      return true;
    } catch (_) {    // ← SWALLOWS ALL
      return false;
    }
}
```

**Why it's broken:** On Android scoped storage, `dir.list()` can throw `FileSystemException: Permission denied` even when `dir.exists()` returns `true`. This exception is swallowed by `catch (_)` and `false` is returned — but there is NO log, NO error message explaining WHY the directory is unreadable.

**Impact:** `loadDirectory()` receives `false` and sets `_error = 'Cannot read this directory'` — which IS shown to the user. So this path at least provides user feedback. However, in `loadAllDirectories`, the `false` return causes the path to be silently skipped (the try block returns early without adding files), and the `catch (_) {}` on line 113 ensures no error propagates. The net effect: folders silently disappear from the aggregated result.

---

### 🟠 SILENT POINT #5 — `_fileCache` returns stale empty results

**File:** `lib/providers/app_state.dart`  
**Lines:** 54-55, 107-108

```dart
// In loadDirectory:
_files = _fileCache.containsKey(path)
    ? List.unmodifiable(_fileCache[path]!)      // ← stale cache
    : await FileService.scanDirectoryRecursive(...);

// In loadAllDirectories:
final dirFiles = _fileCache.containsKey(path)
    ? _fileCache[path]!                          // ← stale cache
    : await FileService.scanDirectoryRecursive(...);
```

**Why it's broken:** If a scan fails silently (returns `[]`), that empty list is cached under the path. Subsequent calls for the SAME path will return the cached empty list WITHOUT re-scanning. The only way to clear the cache is `refresh()` (pull-to-refresh or explicit call).

**Impact scenario:**
1. User opens app → permission denied → scan returns `[]` → cached as `[]`
2. User grants permission in system settings, returns to app
3. Re-opening the same folder hits the cache → returns stale empty `[]` → "No PDFs found"
4. User thinks the fix didn't work, when it actually did — they just need a pull-to-refresh

---

### 🟠 SILENT POINT #6 — `_loadInitialData` fallback chain incomplete

**File:** `lib/screens/home_screen.dart`  
**Lines:** 44-52

```dart
Future<void> _loadInitialData() async {
    // ...
    final persisted = await pathsProvider.loadPersistedDir();
    if (persisted != null && await Directory(persisted).exists()) {
      await appState.loadDirectory(persisted);       // Path A
    } else if (pathsProvider.scannedPaths.isNotEmpty) {
      await appState.loadAllDirectories(pathsProvider.scannedPaths);  // Path B
    }
    // If Path A fails silently and Path B is never checked, user sees nothing
}
```

**Why it's broken:** If Path A fires (persisted dir exists) and `loadDirectory()` completes successfully but returns zero files (silent failure in isolate), the `else if` for Path B NEVER fires. If the user also has other scanned paths that might work, those are never loaded.

**Impact:** User loses access to all other scanned folders because the code only tries the persisted directory.

---

## 3. Android Scoped Storage Analysis

The Android manifest has the right permissions declared:
```xml
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"/>
```
And `permission_service.dart` correctly targets `MANAGE_EXTERNAL_STORAGE` for SDK 30+.

However, there are three runtime concerns:

1. **`Permission.manageExternalStorage.request()` on Android 11+ does NOT show a permission dialog.** It either returns `isGranted` immediately (if already granted) or `isDenied`. The user must navigate to Settings → Apps → Special Access → All Files Access to grant it manually. The comment in `permission_service.dart` line 37 says "This will show a dialog" — this is incorrect.

2. **`requestLegacyExternalStorage="true"` has no effect on Android 11+.** It only applies to Android 10 (API 29). On Android 11+, `MANAGE_EXTERNAL_STORAGE` is the only path.

3. **Even with `MANAGE_EXTERNAL_STORAGE` granted, `Directory.existsSync()` in an Isolate may behave differently** than on the main thread. Some Android OEMs (Xiaomi, Huawei, Samsung) have additional filesystem restrictions that apply differently across threads.

---

## 4. Root Cause(s) — Ranked by Likelihood

| Rank | Root Cause | Evidence | Probability |
|------|-----------|----------|-------------|
| **1** | `catch (_) {}` in `loadAllDirectories` swallows all scan failures | Line 113 in `app_state.dart` — zero logging, zero error propagation | **High** |
| **2** | `debugPrint` in Isolate is invisible → all scan errors lost | 4 debugPrint calls in `scanDirectoryRecursive` are in an isolate | **High** |
| **3** | `existsSync()` returns `false` silently on scoped storage | No error log, just returns `[]` — matches "silently failing" description exactly | **Medium-High** |
| **4** | `isReadable()` swallows permission exceptions without logging | `catch (_)` at line 134 in `file_service.dart` | **Medium** |
| **5** | `_fileCache` caches stale empty results | `containsKey` check skips re-scan on line 54 and 107 | **Medium** |
| **6** | Fallback chain in `_loadInitialData` skips other paths | `else if` on line 49 in `home_screen.dart` prevents Path B | **Low-Medium** |

**Combined effect:** If #1 and #2 are both active — which they always are — every filesystem or permission error during directory scanning is swallowed at TWO levels with zero trace. This creates the "silently failing" symptom perfectly.

---

## 5. Proposed Fixes (Ranked by Likelihood of Being the Actual Bug)

### Fix Package A: Eliminate Silent Error Swallowing (MUST FIX)

#### A1. `loadAllDirectories` — Log and propagate errors
**File:** `lib/providers/app_state.dart`, line 113

Replace `catch (_) {}` with:
```dart
} catch (e, stack) {
  debugPrint('AppState: failed to scan directory $path: $e\n$stack');
  return <PdfFile>[];
}
```

#### A2. Replace all `debugPrint` in Isolate with real logging
**File:** `lib/services/file_service.dart`, lines 23, 28, 55, 67

**Option 1 (best):** Collect errors in the isolate, return them alongside files:
```dart
return Isolate.run(() {
  final errors = <String>[];
  // ... replace debugPrint with errors.add(...)
  return _ScanResult(pdfFiles, errors);
});
```
Then log errors on the main thread after the isolate completes.

**Option 2 (simpler):** Use `print()` instead of `debugPrint()` — `print()` writes to logcat even from isolates on Android.

#### A3. Add logging to `existsSync()` failure
**File:** `lib/services/file_service.dart`, line 47

```dart
if (!dir.existsSync()) {
  // Collect this as an error to report after the isolate
  errors.add('Directory does not exist or is not accessible: $dirPath');
  return _ScanResult([], errors);
}
```

#### A4. Add logging to `isReadable()`
**File:** `lib/services/file_service.dart`, line 134

```dart
} catch (e) {
  debugPrint('FileService.isReadable: $path → $e');
  return false;
}
```

### Fix Package B: Fix Caching (SHOULD FIX)

#### B1. Invalidate cache on error
**File:** `lib/providers/app_state.dart`

Don't cache empty results from failed scans. Only cache if `dirFiles.isNotEmpty` or add a flag indicating the scan was successful.

#### B2. Add cache expiry or invalidation on app resume
**File:** `lib/providers/app_state.dart`

Clear `_fileCache` in `refresh()` — already done ✅ — but also consider clearing when the app resumes from background (in case permissions changed while app was backgrounded).

### Fix Package C: Fix Fallback Chain (SHOULD FIX)

#### C1. Always try fallback paths
**File:** `lib/screens/home_screen.dart`, lines 44-52

```dart
bool loaded = false;
if (persisted != null && await Directory(persisted).exists()) {
  await appState.loadDirectory(persisted);
  loaded = appState.files.isNotEmpty || appState.error != null;
}
if (!loaded && pathsProvider.scannedPaths.isNotEmpty) {
  await appState.loadAllDirectories(pathsProvider.scannedPaths);
}
```

### Fix Package D: Fix Permission Flow (SHOULD FIX)

#### D1. Fix incorrect comment about permission dialog
**File:** `lib/services/permission_service.dart`, line 37

Replace the misleading comment. Add actual `openAppSettings()` call when permission is denied.

#### D2. Verify `MANAGE_EXTERNAL_STORAGE` before Isolate scan
**File:** `lib/services/file_service.dart`

Before spawning the isolate, verify the permission is actually granted (not just declared). If not granted, return an explicit error rather than running the isolate.

---

## 6. Files That Need Changes

| File | Changes | Priority |
|------|---------|----------|
| `lib/providers/app_state.dart` | Fix `catch (_) {}` on line 113, add error logging, fix cache staleness | **Critical** |
| `lib/services/file_service.dart` | Replace `debugPrint` with error collection in isolate, add logging to `existsSync()`, add logging to `isReadable()`, verify permission before isolate | **Critical** |
| `lib/screens/home_screen.dart` | Fix `_loadInitialData` fallback chain | **High** |
| `lib/services/permission_service.dart` | Fix misleading comment, add better permission flow | **Medium** |

---

## 7. Testing Checklist for the Fix

After fixes are applied, verify these scenarios:

1. ✅ App launch with valid persisted dir AND PDFs → files appear
2. ✅ App launch with valid persisted dir but no permission → user gets clear error, not silent "No PDFs found"
3. ✅ App launch with `MANAGE_EXTERNAL_STORAGE` denied → directed to settings
4. ✅ Scanning a deep directory tree (>10 levels) → doesn't silently stop
5. ✅ Scanning a directory with permission-denied subdirectories → remaining files still appear
6. ✅ Pull-to-refresh after adding new PDFs to folder → new files appear
7. ✅ Scoped storage on Android 11+ (Samsung, Xiaomi, Pixel) → files found
8. ✅ "Open with" intent while scanning in progress → doesn't crash
9. ✅ Isolate crash during scan → error propagated to UI, not swallowed
10. ✅ Empty directory → "No PDFs found" (correct behavior, not a bug)
