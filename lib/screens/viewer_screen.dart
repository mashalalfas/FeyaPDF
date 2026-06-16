import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/pdf_file.dart';
import '../providers/encryption_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/file_operations_provider.dart';
import '../widgets/passphrase_dialog.dart';

class ViewerScreen extends StatefulWidget {
  final PdfFile file;
  const ViewerScreen({super.key, required this.file});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  PdfViewerController? _pdfController;
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 0;
  PdfDocumentRef? _documentRef;

  // Cached link annotations per page (loaded async when document is ready)
  final Map<int, List<PdfLink>> _pageLinks = {};

  // SVG-specific state
  bool _isSvgFile = false;
  String? _svgError;

  // Outline / table of contents state
  List<PdfOutlineNode>? _outline;
  bool _outlineLoading = false;

  // Seek-to-page state (tapping the page counter)
  bool _showPageSeek = false;
  final _pageSeekController = TextEditingController();
  final _pageSeekFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _isSvgFile = widget.file.path.endsWith('.svg');
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    // --- SVG branch ---
    if (_isSvgFile) {
      try {
        if (!await widget.file.file.exists()) {
          if (mounted) {
            setState(() {
              _error = 'File not found:\n${widget.file.path}';
              _isLoading = false;
            });
          }
          return;
        }
        if (mounted) {
          setState(() => _isLoading = false);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _svgError = 'Failed to open SVG: $e';
            _isLoading = false;
          });
        }
      }
      return;
    }

    // --- PDF branch ---
    // Read all providers upfront before any async gap
    final encryption = context.read<EncryptionProvider>();
    final settings = context.read<SettingsProvider>();
    final fileOps = context.read<FileOperationsProvider>();

    final lastPage = settings.getLastReadPage(widget.file.path);
    final initialPage = (lastPage != null && lastPage > 0) ? lastPage : 1;

    // If encrypted and no passphrase, prompt
    if (widget.file.isEncrypted && !encryption.hasPassphrase) {
      final set = await showPassphraseDialog(context);
      if (!set || !mounted) {
        if (mounted) Navigator.pop(context);
        return;
      }
    }

    try {
      // Check file exists
      if (!await widget.file.file.exists()) {
        if (mounted) {
          setState(() {
            _error = 'File not found:\n${widget.file.path}';
            _isLoading = false;
          });
        }
        return;
      }

      // Build the PdfDocumentRef for this source
      if (widget.file.isEncrypted) {
    final bytes = await fileOps.getPdfBytes(widget.file);
        if (bytes == null || bytes.isEmpty || !mounted) {
          if (mounted) {
            setState(() {
              _error = 'Decryption failed — wrong passphrase?';
              _isLoading = false;
            });
          }
          return;
        }

        // Warn about large encrypted files (can't lazy-load these)
        if (widget.file.sizeBytes > 100 * 1024 * 1024 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Large encrypted PDF — may take a moment to load'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        _documentRef = PdfDocumentRefData(
          bytes,
          sourceName: widget.file.path,
          useProgressiveLoading: false,
        );
      } else {
        // Unencrypted: open via file path (memory-mapped / lazy page loading)
        _documentRef = PdfDocumentRefFile(
          widget.file.path,
          useProgressiveLoading: true,
        );
      }

      // Create controller — pageCount/pageNumber are available after viewer is ready
      _pdfController = PdfViewerController();

      if (mounted) {
        setState(() {
          _currentPage = initialPage;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to open PDF: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Load link annotations for a given page and cache them.
  Future<void> _loadPageLinks(PdfDocument document, int pageNumber) async {
    if (_pageLinks.containsKey(pageNumber)) return;
    try {
      final page = document.pages[pageNumber - 1];
      final links = await page.loadLinks(compact: true);
      if (mounted) {
        setState(() {
          _pageLinks[pageNumber] = links;
        });
      }
    } catch (_) {
      // Silently ignore — links are optional; render nothing on failure
    }
  }

  /// Called when the PdfViewer finishes loading the document.
  void _onViewerReady(PdfDocument? document, PdfViewerController controller) {
    if (document == null) return;
    if (mounted) {
      setState(() {
        _totalPages = document.pages.length;
        _currentPage = controller.pageNumber ?? _currentPage;
      });
    }
    // Pre-load links for the currently visible page
    _loadPageLinks(document, controller.pageNumber ?? _currentPage);
    // Pre-load outline in the background
    _loadOutline(document);
  }

  /// Load the PDF outline (table of contents) in the background.
  Future<void> _loadOutline(PdfDocument document) async {
    if (_outline != null || _outlineLoading) return;
    _outlineLoading = true;
    try {
      final nodes = await document.loadOutline();
      if (mounted) {
        setState(() => _outline = nodes);
      }
    } catch (_) {
      // Silently ignore — outline is optional
    } finally {
      if (mounted) {
        setState(() => _outlineLoading = false);
      }
    }
  }

  /// Called when the viewer notifies a page change.
  void _onPageChanged(int? pageNumber) {
    if (pageNumber == null || pageNumber == _currentPage) return;
    final document = _documentRef?.resolveListenable().document;
    if (document != null && pageNumber > 0 && pageNumber <= document.pages.length) {
      _loadPageLinks(document, pageNumber);
    }
    if (mounted) {
      setState(() => _currentPage = pageNumber);
      context.read<SettingsProvider>().setLastReadPage(widget.file.path, pageNumber);
    }
  }

  /// Called when the document reference notifies a document change (load / reload).
  void _onDocumentChanged(PdfDocument? document) {
    if (document == null || !mounted) return;
    setState(() => _totalPages = document.pages.length);
  }

  @override
  void dispose() {
    _pageSeekController.dispose();
    _pageSeekFocus.dispose();
    // PdfViewerController is a ValueListenable; it is cleaned up by the PdfViewer widget.
    // PdfDocumentRef auto-disposes the underlying document when autoDispose=true (default).
    super.dispose();
  }

  Future<void> _shareFile() async {
    final fileOps = context.read<FileOperationsProvider>();
    await fileOps.shareFile(widget.file.path);
  }

  Future<void> _saveToLocal() async {
    final fileOps = context.read<FileOperationsProvider>();

    // Ask user to pick a destination directory
    final destDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose save destination',
    );
    if (destDir == null || !mounted) return;

    final (result, newPath) = await fileOps.saveToLocal(
      widget.file.path,
      targetDir: destDir,
    );
    if (!mounted) return;

    switch (result) {
      case SaveResult.failure:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save file'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      case SaveResult.alreadyExists:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Already exists in:\n$destDir'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      case SaveResult.success:
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved to:\n$destDir'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// FEATURE 1.2 — Show PDF outline / table of contents as a bottom sheet.
  void _showOutline() {
    final controller = _pdfController;
    if (controller == null) return;

    final outline = _outline;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.92,
          expand: false,
          builder: (ctx, scrollController) {
            if (outline == null || outline.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.list_alt_rounded,
                      size: 48,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _outlineLoading
                          ? 'Loading contents…'
                          : 'No table of contents',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 15,
                      ),
                    ),
                    if (_outlineLoading) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Handle bar
                Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    children: [
                      Icon(Icons.list_alt_rounded,
                          size: 20, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Contents',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: cs.outlineVariant.withValues(alpha: 0.3)),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _flattenOutline(outline).length,
                    itemBuilder: (_, index) {
                      final item = _flattenOutline(outline)[index];
                      return _buildOutlineTile(ctx, item.node, item.depth);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Flatten the outline tree into a list of (node, depth) pairs.
  List<({PdfOutlineNode node, int depth})> _flattenOutline(
    List<PdfOutlineNode> nodes, [
    int depth = 0,
  ]) {
    final result = <({PdfOutlineNode node, int depth})>[];
    for (final node in nodes) {
      result.add((node: node, depth: depth));
      result.addAll(_flattenOutline(node.children, depth + 1));
    }
    return result;
  }

  /// Build a single outline entry tile.
  Widget _buildOutlineTile(
    BuildContext ctx,
    PdfOutlineNode node,
    int depth,
  ) {
    final controller = _pdfController;
    final cs = Theme.of(ctx).colorScheme;
    final hasDest = node.dest != null;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.only(
        left: 16.0 + depth * 20.0,
        right: 16,
      ),
      leading: Icon(
        hasDest ? Icons.article_outlined : Icons.folder_outlined,
        size: 18,
        color: hasDest
            ? cs.onSurfaceVariant.withValues(alpha: 0.7)
            : cs.primary.withValues(alpha: 0.6),
      ),
      title: Text(
        node.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight:
              depth == 0 ? FontWeight.w600 : FontWeight.w400,
          color: cs.onSurface,
        ),
      ),
      onTap: hasDest
          ? () {
              Navigator.pop(ctx);
              if (controller != null) {
                controller.goToDest(node.dest);
              }
            }
          : null,
      enabled: hasDest,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (widget.file.isEncrypted) ...[
              Icon(Icons.lock_rounded, size: 16, color: colorScheme.tertiary),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                widget.file.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        actions: [
          // FEATURE 1.2 — Outline / ToC button
          if (!_isSvgFile && _totalPages > 0)
            IconButton(
              icon: Icon(
                Icons.list_alt_rounded,
                size: 20,
                color: _outline != null && _outline!.isNotEmpty
                    ? colorScheme.primary
                    : null,
              ),
              tooltip: 'Table of Contents',
              onPressed: _showOutline,
            ),
          // FEATURE 1: Save icon is always visible
          IconButton(
            icon: const Icon(Icons.save_alt_rounded, size: 20),
            tooltip: 'Save to folder',
            onPressed: _saveToLocal,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 20),
            tooltip: 'Share',
            onPressed: _shareFile,
          ),
        ],
      ),
      body: _buildBody(colorScheme, settings),
      bottomNavigationBar: !_isSvgFile && _totalPages > 0
          ? _buildPageIndicator(colorScheme)
          : null,
    );
  }

  Widget _buildBody(ColorScheme colorScheme, SettingsProvider settings) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              _isSvgFile ? 'Loading SVG...' : (widget.file.isEncrypted ? 'Decrypting...' : 'Loading PDF...'),
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                    _svgError = null;
                  });
                  _loadPdf();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // --- SVG preview (FEATURE 2) ---
    if (_isSvgFile) {
      return _buildSvgBody(colorScheme);
    }

    // --- PDF viewer ---
    if (_documentRef == null || _pdfController == null) {
      return const Center(child: Text('No PDF loaded'));
    }

    return PdfViewer(
      _documentRef!,
      controller: _pdfController,
      initialPageNumber: _currentPage,
      params: PdfViewerParams(
        // FEATURE 1.5 — Continuous scroll mode vs single-page mode
        layoutPages: settings.continuousScroll
            ? (pages, params) {
                var y = params.margin;
                final layouts = <Rect>[];
                for (final page in pages) {
                  layouts.add(Rect.fromLTWH(
                    params.margin,
                    y,
                    page.width,
                    page.height,
                  ));
                  y += page.height + params.margin;
                }
                return PdfPageLayout(
                  pageLayouts: layouts,
                  documentSize: Size(
                    pages.isEmpty ? 0 : pages.first.width + params.margin * 2,
                    y,
                  ),
                );
              }
            : null,
        // FEATURE 3 — Annotations / links overlay
        // pdfrx renders annotations natively (forms + appearances) by default
        // via PdfAnnotationRenderingMode.annotationAndForms.
        // We additionally render link annotations as overlay widgets
        // so that interactive regions (URL links, internal destinations)
        // are visually indicated to the user.
        pageOverlaysBuilder: (context, pageRect, page) {
          final pageLinks = _pageLinks[page.pageNumber];
          if (pageLinks == null || pageLinks.isEmpty) return [];
          return pageLinks.map((link) {
            // Render each link annotation as a translucent highlight badge
            // at the first rect in the link's rect list.
            final rect = link.rects.isNotEmpty ? link.rects.first : null;
            if (rect == null) return const SizedBox.shrink();
            return Positioned(
              left: pageRect.left + rect.left,
              top: pageRect.top + rect.top,
              child: Container(
                width: rect.width,
                height: rect.height,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: link.url != null
                    ? const Align(
                        alignment: Alignment.topRight,
                        child: Icon(
                          Icons.link_rounded,
                          size: 12,
                          color: Colors.blue,
                        ),
                      )
                    : null,
              ),
            );
          }).toList();
        },
        onDocumentChanged: _onDocumentChanged,
        onViewerReady: _onViewerReady,
        onPageChanged: _onPageChanged,
      ),
    );
  }

  /// Build the SVG preview body (FEATURE 2).
  /// Uses flutter_svg's SvgPicture.file for rendering inside an InteractiveViewer
  /// for pinch-to-zoom support. Falls back to a placeholder icon on error.
  Widget _buildSvgBody(ColorScheme colorScheme) {
    if (_svgError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'SVG preview unavailable',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              _svgError!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    try {
      return InteractiveViewer(
        minScale: 0.25,
        maxScale: 10.0,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SvgPicture.file(
              widget.file.file,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      // Fallback: placeholder icon when flutter_svg can't render
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined, size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'SVG preview unavailable',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPageIndicator(ColorScheme colorScheme) {
    final controller = _pdfController;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    void seekToPage(String input) {
      final parsed = int.tryParse(input.trim());
      if (parsed != null && parsed >= 1 && parsed <= _totalPages) {
        controller.goToPage(pageNumber: parsed);
      }
      setState(() {
        _showPageSeek = false;
        _pageSeekController.clear();
      });
      _pageSeekFocus.unfocus();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // FEATURE 5.2 — First Page button
            IconButton(
              icon: const Icon(Icons.first_page_rounded),
              onPressed: _currentPage > 1
                  ? () => controller.goToPage(pageNumber: 1)
                  : null,
              iconSize: 22,
              visualDensity: VisualDensity.compact,
              tooltip: 'First page',
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: _currentPage > 1
                  ? () => controller.goToPage(pageNumber: _currentPage - 1)
                  : null,
              iconSize: 24,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            // FEATURE 5.2 — Tappable page counter → inline seek
            _showPageSeek
                ? SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _pageSeekController,
                      focusNode: _pageSeekFocus,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: colorScheme.primary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        hintText: '$_totalPages',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      onSubmitted: seekToPage,
                      onTapOutside: (_) => seekToPage(_pageSeekController.text),
                    ),
                  )
                : GestureDetector(
                    onTap: () {
                      setState(() => _showPageSeek = true);
                      _pageSeekController.text = '';
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_currentPage / $_totalPages',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: _currentPage < _totalPages
                  ? () => controller.goToPage(pageNumber: _currentPage + 1)
                  : null,
              iconSize: 24,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            // FEATURE 5.2 — Last Page button
            IconButton(
              icon: const Icon(Icons.last_page_rounded),
              onPressed: _currentPage < _totalPages
                  ? () => controller.goToPage(pageNumber: _totalPages)
                  : null,
              iconSize: 22,
              visualDensity: VisualDensity.compact,
              tooltip: 'Last page',
            ),
          ],
        ),
      ),
    );
  }
}
