import 'package:flutter/material.dart';
import '../models/pdf_file.dart';

enum SortBy { name, modified, size }
enum SortOrder { asc, desc }

class SortSearchProvider extends ChangeNotifier {
  SortBy _sortBy = SortBy.modified;
  SortOrder _sortOrder = SortOrder.desc;
  String _searchQuery = '';

  SortBy get sortBy => _sortBy;
  SortOrder get sortOrder => _sortOrder;
  String get searchQuery => _searchQuery;

  set sortBy(SortBy value) {
    _sortBy = value;
    notifyListeners();
  }

  set sortOrder(SortOrder value) {
    _sortOrder = value;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<PdfFile> apply(List<PdfFile> files) {
    var sorted = List<PdfFile>.from(files);

    // Apply sorting
    sorted.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case SortBy.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case SortBy.modified:
          cmp = a.modified.compareTo(b.modified);
        case SortBy.size:
          cmp = a.sizeBytes.compareTo(b.sizeBytes);
      }
      return _sortOrder == SortOrder.asc ? cmp : -cmp;
    });

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      sorted = sorted.where((f) => f.name.toLowerCase().contains(q)).toList();
    }

    return sorted;
  }
}
