import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// A ChangeNotifier that bridges the search bar UI callbacks with pdfrx's
/// built-in [PdfTextSearcher] for text search, match navigation, and
/// match highlighting on PDF pages.
class SearchProvider extends ChangeNotifier {
  PdfTextSearcher? _searcher;
  List<PdfPageTextRange> _matches = const [];

  /// Whether a search task is currently running.
  bool get isSearching => _searcher?.isSearching ?? false;

  /// The total number of matches found.
  int get matchCount => _matches.length;

  /// The 0-based index of the currently active match.
  int get currentMatchIndex => _searcher?.currentIndex ?? 0;

  /// All matches found by the current search.
  List<PdfPageTextRange> get matches => _matches;

  /// Attach to a [PdfViewerController] to enable searching.
  ///
  /// Call this once the PDF viewer controller is ready (e.g. in
  /// [PdfViewerParams.onViewerReady]).
  void attach(PdfViewerController controller) {
    detach();
    _searcher = PdfTextSearcher(controller);
    _searcher!.addListener(_onSearcherChanged);
  }

  /// Detach from the controller and release resources.
  void detach() {
    _searcher?.removeListener(_onSearcherChanged);
    _searcher?.dispose();
    _searcher = null;
    _matches = const [];
    notifyListeners();
  }

  void _onSearcherChanged() {
    _matches = _searcher?.matches ?? const [];
    notifyListeners();
  }

  /// Start searching for [query] within the PDF document.
  ///
  /// If [query] is empty, the current search is cleared.
  void search(String query) {
    if (query.isEmpty) {
      _searcher?.resetTextSearch();
      _matches = const [];
      notifyListeners();
      return;
    }
    _searcher?.startTextSearch(
      query,
      goToFirstMatch: true,
      searchImmediately: true,
    );
  }

  /// Navigate to the next match in the results.
  Future<void> nextMatch() async {
    await _searcher?.goToNextMatch();
  }

  /// Navigate to the previous match in the results.
  Future<void> previousMatch() async {
    await _searcher?.goToPrevMatch();
  }

  /// Clear the current search results and reset the search state.
  void clearSearch() {
    _searcher?.resetTextSearch();
    _matches = const [];
    notifyListeners();
  }

  /// Paint callback to render match highlight rectangles on PDF pages.
  ///
  /// Add this to [PdfViewerParams.pagePaintCallbacks] so that matches are
  /// drawn as overlays on each page. The current (active) match is rendered
  /// in yellow; other matches in light gray.
  void pagePaintCallback(ui.Canvas canvas, Rect pageRect, PdfPage page) {
    _searcher?.pageTextMatchPaintCallback(canvas, pageRect, page);
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
