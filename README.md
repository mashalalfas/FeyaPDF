# Melody PDF

A clean, fast, ad-free PDF reader for Android with E2E encryption and annotation support.

## Features

- **PDF viewing** with pdfrx — native annotation rendering, pinch-zoom, page navigation
- **E2E encryption** — AES-256-GCM, PBKDF2 key derivation, .pdf.enc format
- **Secure folder** — dedicated encrypted directory for sensitive files
- **Tag system** — 8-color palette, filter bar, management screen
- **SVG preview** — vector file support via flutter_svg
- **File management** — sort by name/date/size, search, save-to-directory
- **Recent files** — quick access to last 5 opened files
- **Multi-folder scanning** — recursive PDF discovery with Isolate
- **"Open with" support** — native Android intent handler

## Stack

- **Framework:** Flutter 3.x
- **State management:** Provider
- **PDF rendering:** pdfrx (native annotations)
- **Encryption:** AES-256-GCM (encrypt package + pointycastle)
- **Storage:** SharedPreferences
- **SVG:** flutter_svg
- **CI:** GitHub Actions (analyze + test on push/PR)

## Test coverage

| Layer | Count | What |
|-------|-------|------|
| Unit (small) | 4 files | Encryption, file, tag, settings services |
| Integration (medium) | 3 files | AppState, TagProvider, FileOperations |
| Widget (large) | 2 files | App root, viewer screen states |

Total: 99 test cases across 9 files. 3-layer addyosmani pyramid.

`dart analyze` → 0 issues

## Build

```bash
flutter pub get
flutter build apk --release
```

## CI

GitHub Actions runs on every push/PR:
1. `dart analyze`
2. `flutter test` (fast tests; 1MB encryption round-trip excluded — 50s)

## Learnings

- Army protocol: max 2-3 files per soldier, decompose before spawning
- Don't give full builds to single agents — slice by layer
- RED→GREEN→REFACTOR catches more bugs than post-hoc tests
