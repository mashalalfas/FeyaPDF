# Council Proposals — FeyaPDF Feature Roadmap

> **Deliberated:** 2026-06-16  
> **Stakeholder Review:** 2026-06-16 — Mashal  
> **Council Role:** Strategic planning body  
> **Basis:** Full codebase audit of `~/Development/FeyaPDF` (37 lib files, 10 test files, 9 providers, 6 services, 4 screens, 9 widgets)  
> **Analysis:** `dart analyze` is clean (0 issues), 9 test suites, 99+ test cases. Foundation is solid but feature breadth is narrow.

---

## Executive Summary

FeyaPDF is a **well-architected PDF reader** with strong foundation: E2E encryption, tagging, secure folder, clean provider-based state.
However, it's essentially a **viewer + encryptor** — it opens PDFs and encrypts them. The gap between "PDF viewer" and "PDF tool" is wide.

**After stakeholder review**, the feature set has been trimmed to 12 proposals focused on core reading, annotation, and security — no sticky notes, freehand drawing, batch operations, merge/split, or iOS/Desktop support.

---

## Category 1: Core PDF Reading Experience

### 1.1 — In-PDF Text Search 🔍

| Field | Detail |
|-------|--------|
| **What** | Search for text _inside_ the currently open PDF. Highlight matches, navigate between hits, show match count. |
| **Why** | Currently users can only search _file names_ on the home screen. Searching content inside a 200-page contract or textbook is table-stakes for any PDF reader. The biggest productivity gap. |
| **User value** | **Critical.** Users trying to find information inside documents must currently scroll manually. |
| **Complexity** | **Medium.** `pdfrx` exposes `PdfDocument.pages[].loadText()` for text extraction. Requires a search state machine (query → async text load per page → aggregate results → highlight overlay). 3–5 files touched: new search bar widget in viewer, search result overlay, provider for search state. |

### 1.2 — PDF Outline / Table of Contents 📑

| Field | Detail |
|-------|--------|
| **What** | Show the PDF's internal outline (chapter headings, sections) as a navigable sidebar. Tapping a heading jumps to the corresponding page. |
| **Why** | PDFs with large TOCs (manuals, books, spec documents) are nearly unusable without outline navigation. pdfrx already exposes this data — the data is there, just not rendered. |
| **User value** | **High.** Transforms navigation for multi-section documents. |
| **Complexity** | **Low.** `pdfrx` provides `PdfDocument.outline` which returns tree-structured outline nodes with page references. Requires: a drawer or bottom sheet with an `ExpansionTile` tree, and a `goToPage()` call on tap. ~2 files touched. |

### 1.3 — Page Thumbnail Grid 🖼️ (Settings Toggle)

| Field | Detail |
|-------|--------|
| **What** | A grid of page thumbnail previews, accessed from the viewer. Tap a thumbnail to jump to that page. **Toggle on/off from Settings** — not always visible. |
| **Why** | Current page navigation is a basic "12 / 45" counter with arrow buttons. No visual cues for what's on each page. Especially needed for image-heavy PDFs and presentations, but users may prefer it hidden to save screen space. |
| **User value** | **High.** Visual navigation is the fastest way to locate pages. |
| **Complexity** | **Medium.** `pdfrx` supports page rasterization via `PdfDocument.pages[].render()` → images. Requires: a `GridView.builder`, thumbnail caching (memory-sensitive), lazy loading for large documents, Settings toggle to show/hide. 3–4 files touched. |

### 1.4 — Dark / Inverse Reading Mode 🌙

| Field | Detail |
|-------|--------|
| **What** | Apply a color inversion or sepia overlay to the PDF rendering — dark background with light text for night reading. Toggle from the viewer toolbar. |
| **Why** | Reading PDFs at night with a bright white background causes eye strain. Users switch to the app's dark theme expecting PDFs to follow, but the PDF canvas stays white. |
| **User value** | **Medium-High.** Quality of life for nighttime readers. |
| **Complexity** | **Low.** Can be achieved via a `ColorFiltered` widget wrapping the `PdfViewer`, or a `ShaderMask`. No pdfrx changes needed. ~1 file touched. |

### 1.5 — Continuous Scroll Mode 📜

| Field | Detail |
|-------|--------|
| **What** | Switch between single-page view (current) and vertical continuous scroll (all pages in one scrollable column). Toggle from the viewer toolbar. |
| **Why** | Single-page mode is disorienting for long-form reading. Continuous scroll is the default in most modern PDF readers (Google Drive, Apple Books). |
| **User value** | **Medium.** Subjective reading preference, but widely expected. |
| **Complexity** | **Low.** `pdfrx` supports `PdfViewerParams.layoutPages` for vertical scroll layout. Requires a toggle button and a provider field. ~2 files touched. |

---

## Category 2: PDF Annotation ✏️

### 2.1 — Text Highlighting 🖍️

| Field | Detail |
|-------|--------|
| **What** | Select text on a page and apply a highlight annotation. Colors: yellow, green, blue, pink, orange. Stored per-page, per-file. |
| **Why** | This is a table-stakes PDF reader feature. Students highlight textbooks. Lawyers highlight contracts. Researchers highlight papers. Without it, FeyaPDF can't replace a basic reader for these use cases. |
| **User value** | **Critical.** Annotation is why most users open a PDF reader instead of just viewing in a browser. |
| **Complexity** | **High.** Requires: (a) text selection gesture handling in the viewer, (b) a highlight data model, (c) rendering highlight overlays on top of pdfrx pages, (d) persisting highlights per file (JSON sidecar alongside PDF), (e) UI for highlight color picker and deletion. 5–8 files touched. |

---

## Category 3: File Operations

### 3.1 — Export PDF as Images 📸

| Field | Detail |
|-------|--------|
| **What** | Export one or all pages of a PDF as PNG/JPEG images. Choose quality and resolution. |
| **Why** | Sharing a single page as an image, embedding in presentations, sending via messaging apps that don't support PDF. |
| **User value** | **Low-Medium.** Niche but useful when needed. |
| **Complexity** | **Medium.** `pdfrx` already rasterizes pages for display. Requires writing raster output to image files. ~3 files touched. |

---

## Category 4: Security & Access

### 4.1 — Biometric Unlock (Fingerprint / Face) 🔐

| Field | Detail |
|-------|--------|
| **What** | Enable biometric authentication to unlock the passphrase. The passphrase is stored encrypted with Android Keystore, unlocked via biometric. App opens → fingerprint → passphrase auto-loaded → encrypted files accessible. |
| **Why** | Typing a passphrase every time the app opens is tedious and reduces adoption of the encryption feature. Biometrics maintain security while improving UX dramatically. |
| **User value** | **High.** Makes encryption usable in practice. |
| **Complexity** | **Medium.** Requires: `local_auth` package for biometric prompt, Android Keystore integration via platform channel for secure passphrase storage, a biometric settings toggle. 4–5 files touched. |

### 4.2 — Passphrase Strength Meter 💪

| Field | Detail |
|-------|--------|
| **What** | Show a real-time strength indicator (weak/fair/strong/very strong) when setting a passphrase. Enforce minimum length (8+ characters). Warn on common passwords. |
| **Why** | Currently any string is accepted. "password" works. Users need guidance to set strong passphrases since there's no recovery mechanism. |
| **User value** | **Medium.** Proactive protection — costs nothing, prevents disaster. |
| **Complexity** | **Low.** Client-side entropy estimation. Add a `LinearProgressIndicator` with color coding and a warning label to the passphrase dialog. ~2 files touched. |

### 4.3 — App Lock / Privacy Screen 🔒

| Field | Detail |
|-------|--------|
| **What** | Require passphrase/biometric to open the app at all, not just to access encrypted files. When app is backgrounded, show a blur overlay that can be dismissed with authentication. |
| **Why** | Even unencrypted PDFs may be sensitive. App lock prevents casual snooping when handing your phone to someone. |
| **User value** | **Medium.** Privacy feature common in banking/health apps. |
| **Complexity** | **Low-Medium.** Requires: `AppLifecycleState` listener for background detection, a blur overlay widget, biometric integration (builds on 4.1). ~3 files touched. |

---

## Category 5: Platform & Experience

### 5.1 — Text Selection & Copy 📋

| Field | Detail |
|-------|--------|
| **What** | Select text on a PDF page and copy it to clipboard. Long-press to select, drag handles to adjust, "Copy" button in context menu. |
| **Why** | Currently there is no way to extract text from a PDF. Users screenshot and OCR, which is absurd. |
| **User value** | **High.** Frequently needed for quoting documents, copying addresses, extracting data. |
| **Complexity** | **Medium-High.** `pdfrx` provides text position data via `PdfPage.loadText()`. Requires building a text selection gesture system, selection handles, clipboard integration. 4–5 files touched. |

### 5.2 — Bottom Bar Navigation: Seek + First/Last ⏮⏭

| Field | Detail |
|-------|--------|
| **What** | Enhanced bottom navigation bar with: (a) **First Page** button (⏮) — jumps to page 0, (b) **Page number input** — tap the page counter to type a page number directly (no separate dialog), (c) **Last Page** button (⏭) — jumps to last page. |
| **Why** | The current bar only has ◀ prev / "12 / 45" counter / next ▶. No fast way to reach the start or end of a document. Typing a page number is faster than tapping arrows 50 times. |
| **User value** | **High.** Drastically reduces navigation friction, especially for long documents. |
| **Complexity** | **Low.** Replace the static `Text("$currentPage / $totalPages")` with a tappable `GestureDetector` that opens an inline `TextField` overlay. Add two `IconButton`s for first/last. ~1 file touched. |

---

## Summary Matrix

| # | Feature | Category | Complexity | Priority |
|---|---------|----------|-----------|----------|
| 1.1 | In-PDF Text Search | Reading | Medium | 🔴 Critical |
| 1.2 | PDF Outline / TOC | Reading | Low | 🔴 Critical |
| 1.3 | Page Thumbnail Grid (toggle) | Reading | Medium | 🟠 High |
| 1.4 | Dark Reading Mode | Reading | Low | 🟡 Medium |
| 1.5 | Continuous Scroll | Reading | Low | 🟡 Medium |
| 2.1 | Text Highlighting | Annotation | High | 🔴 Critical |
| 3.1 | Export PDF as Images | File Mgmt | Medium | 🟢 Low |
| 4.1 | Biometric Unlock | Security | Medium | 🟠 High |
| 4.2 | Passphrase Strength | Security | Low | 🟡 Medium |
| 4.3 | App Lock | Security | Low-Med | 🟡 Medium |
| 5.1 | Text Selection & Copy | Platform | Med-High | 🟠 High |
| 5.2 | Bottom Bar (First/Last/Seek) | Platform | Low | 🔴 Critical |

---

## Recommended Implementation Order

```
Phase 1 (Foundation — quick wins):
  5.2  Bottom Bar First/Last/Seek   ← your suggestion, trivial effort
  1.2  PDF Outline / TOC            ← low effort, high impact
  1.5  Continuous Scroll            ← trivial toggle, pdfrx supports it
  4.2  Passphrase Strength          ← trivial, protects users now

Phase 2 (Reading Polish):
  1.1  In-PDF Text Search           ← biggest missing feature
  1.4  Dark Reading Mode            ← low effort, on user wishlist
  1.3  Page Thumbnail Grid          ← settings toggle, builds on 1.1
  5.1  Text Selection & Copy        ← depends on text data from 1.1

Phase 3 (Annotations + Security):
  2.1  Text Highlighting            ← most requested feature, complex
  4.1  Biometric Unlock             ← transforms encryption UX
  4.3  App Lock                     ← builds on 4.1

Phase 4 (Stretch):
  3.1  Export PDF as Images         ← lower demand
```

## Explicitly Rejected (per stakeholder)

| Idea | Reason |
|------|--------|
| Sticky Notes | Cut by stakeholder |
| Freehand Drawing | Cut by stakeholder |
| Batch Operations | Cut by stakeholder |
| File Info Panel | Cut by stakeholder |
| PDF Merge | Cut by stakeholder |
| PDF Split | Cut by stakeholder |
| iOS/Desktop Support | Cut by stakeholder |
| OCR / Scanned PDF Search | Too complex for current scope |
| Cloud Sync | Adds auth/network complexity |
| PDF Form Filling | Low demand |
| TTS / Read Aloud | Nice-to-have, not critical |

---

## Architectural Notes

1. **Annotation storage**: Highlights stored as JSON sidecar files alongside the PDF (e.g., `document.pdf.feya_annotations`), NOT embedded in the PDF itself. Embedding requires PDF modification libraries which Dart lacks.

2. **New provider**: Phase 2–3 will benefit from a `ViewerStateProvider` — currently the viewer screen manages all document state in a StatefulWidget. Extracting to a provider enables clean testing.

3. **Large PDF safety**: Encrypted files are loaded fully into memory (AES-GCM requirement). A 200MB encrypted PDF will still OOM. Per-page encryption is a separate high-effort issue.

4. **Testing**: New providers → unit tests first; new widgets → widget tests; new screens → integration tests.

---

_End of Council Proposals (post-stakeholder-review)._
