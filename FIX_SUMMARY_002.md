# FIX SUMMARY 002 — Failure-Path Test Coverage for Folder Scanning Pipeline

**Date:** 2026-06-15
**Fix Reference:** FIX_SUMMARY_001.md (Silent Folder Scanning Failures)
**File Created:** `test/failure_path_test.dart`

---

## Overview

FIX_SUMMARY_001 patched six silent failure points in the folder scanning pipeline. This test file provides regression coverage for those fixes — verifying that non-existent directories, empty directories, and mixed valid/invalid paths are handled gracefully without crashes or silent data loss. The tests also validate the cache invalidation fix (Fix #2 from FIX_SUMMARY_001) and the error-collection isolate fix (Fix #4).

## Tests Created

### File: `test/failure_path_test.dart`

| # | Test Name | What It Guards |
|---|-----------|----------------|
| 1 | `scanDirectoryRecursive with non-existent directory returns empty list` | Isolate crash safety when directory doesn't exist (Fix #6) |
| 2 | `scanDirectoryRecursive with empty directory returns empty list` | Correct behavior for directories with no PDFs |
| 3 | `scanDirectoryRecursive with PDF files finds them` | Happy-path baseline — confirms scanning still works |
| 4 | `isReadable with non-existent path returns false` | Permission/missing-dir guard (Fix #5) |
| 5 | `isReadable with valid directory returns true` | Confirms normal operation of isReadable |
| 6 | `loadAllDirectories with mix of valid and invalid paths` | Valid files survive invalid-path neighbors (Fix #1 — logged error handling) |
| 7 | `loadAllDirectories with all invalid paths returns empty list` | No crash when all paths are bad |
| 8 | `refresh clears cache so new files on disk are discovered` | Cache invalidation regression test (Fix #2) |
| 9 | `loadDirectory with empty directory returns empty list, no error` | Empty dir ≠ error (contrast with old red error UI) |
| 10 | `loadDirectory with non-existent path does not crash` | Safe handling of bad paths in single-directory load |
| 11 | `scanDirectoryRecursive respects maxDepth limit` | Edge case — depth cap works correctly |
| 12 | `scanDirectory with non-existent path returns empty list` | Non-recursive scan is also safe |
| 13 | `loadAllDirectories with empty paths list clears files` | Empty-path-list contract verified |

### Test Structure

Tests are organized into three groups:

```
FileService failure paths    — Tests 1–5  (low-level service methods)
AppState failure paths        — Tests 6–10 (provider orchestration)
Edge cases                    — Tests 11–13 (boundary conditions)
```

All tests use real `dart:io` temp directories created via `Directory.systemTemp.createTempSync()`, with `setUpAll`/`tearDownAll` lifecycle management. Non-existent paths use hardcoded `/no/such/dir_*` paths to simulate permission-denied or missing-directory scenarios.

### Patterns Followed

- **Arrange/Act/Assert** structure, matching existing `app_state_test.dart` and `file_service_test.dart`
- **Helper functions:** `_makeTempDir(name)`, `_writePdf(parent, name, {sizeBytes})` — same signature as existing tests
- **Import style:** `flutter_test` + targeted project imports (no wildcard)
- **No side effects on existing tests** — completely independent file

## Verification

### Dart Analysis
```
dart analyze test/failure_path_test.dart
→ No issues found.
```

### Failure-Path Tests (isolated)
```
flutter test test/failure_path_test.dart
→ 13/13 tests passed (0 failures, 0 skipped)
```

### Full Test Suite (non-encryption)
```
flutter test test/app_state_test.dart test/file_service_test.dart \
           test/failure_path_test.dart test/file_operations_test.dart \
           test/settings_service_test.dart test/tag_provider_test.dart \
           test/tag_service_test.dart test/widget_test.dart \
           test/viewer_integration_test.dart
→ 112/112 tests passed (0 failures, 0 skipped)
```

> **Note:** `encryption_service_test.dart` has a pre-existing issue with the 1MB large-payload test causing resource exhaustion in the test runner. This is unrelated to the scanning pipeline changes.

### Error Visibility Confirmed

Test output shows the isolate error-collection fix working:
```
FileService: Directory does not exist or not accessible: /no/such/dir_xyz_123
```

## What Was NOT Changed

- No existing test files were modified
- No production code was changed
- No public API signatures altered

## Coverage Map

| Fix from FIX_SUMMARY_001 | Test(s) Covering It |
|--------------------------|---------------------|
| Fix #1 — Logged error handling in `loadAllDirectories` | Test 6, 7 |
| Fix #2 — Don't cache empty results | Test 8 (cache invalidation), Test 9 |
| Fix #4 — Isolate error collection via `_ScanResult` | Test 1, 2, 3 (isolate scanning) |
| Fix #5 — Logging in `isReadable()` | Test 4, 5 |
| Fix #6 — `existsSync()` error in isolate | Test 1 (non-existent dir returns `errors` list) |
