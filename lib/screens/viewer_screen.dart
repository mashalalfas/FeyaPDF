import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdfx/pdfx.dart';
import '../models/pdf_file.dart';
import '../providers/app_state.dart';
import '../providers/encryption_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/passphrase_dialog.dart';

class ViewerScreen extends StatefulWidget {
  final PdfFile file;
  const ViewerScreen({super.key, required this.file});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  PdfControllerPinch? _pdfController;
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  bool get _isExternalFile {
    final path = widget.file.path;
    if (path.contains('/cache/shared_pdfs/')) return true;
    final appState = context.read<AppState>();
    for (final scannedPath in appState.scannedPaths) {
      if (path.startsWith(scannedPath)) return false;
    }
    return true;
  }

  Future<void> _loadPdf() async {
    final appState = context.read<AppState>();
    final encryption = context.read<EncryptionProvider>();
    final settings = context.read<SettingsProvider>();

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

      PdfDocument document;

      if (widget.file.isEncrypted) {
        // Encrypted: must decrypt first, load into memory
        final bytes = await appState.getPdfBytes(widget.file);
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
              duration: Duration(seconds: 3),
            ),
          );
        }

        document = await PdfDocument.openData(bytes);
      } else {
        // Unencrypted: open via file path (memory-mapped / lazy page loading)
        document = await PdfDocument.openFile(widget.file.path);
      }

      final totalPages = document.pagesCount;

      if (totalPages == 0) {
        await document.close();
        if (mounted) {
          setState(() {
            _error = 'PDF has no pages';
            _isLoading = false;
          });
        }
        return;
      }

      // Restore last read position
      final lastPage = settings.getLastReadPage(widget.file.path);
      final initialPage = (lastPage != null && lastPage > 0 && lastPage <= totalPages)
          ? lastPage
          : 1;

      _pdfController = PdfControllerPinch(
        document: Future.value(document),
        initialPage: initialPage,
      );

      setState(() {
        _totalPages = totalPages;
        _currentPage = initialPage;
        _isLoading = false;
      });

      // Listen for page changes
      _pdfController!.addListener(_onPageChanged);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to open PDF: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onPageChanged() {
    if (_pdfController == null) return;
    final page = _pdfController!.page;
    if (page != _currentPage && mounted) {
      setState(() => _currentPage = page);
      // Save last read position
      context.read<SettingsProvider>().setLastReadPage(widget.file.path, page);
    }
  }

  @override
  void dispose() {
    _pdfController?.removeListener(_onPageChanged);
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _shareFile() async {
    await context.read<AppState>().shareFile(widget.file.path);
  }

  Future<void> _saveToLocal() async {
    final appState = context.read<AppState>();
    final (result, newPath) = await appState.saveToLocal(widget.file.path);
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
            content: const Text('Already saved'),
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
        content: const Text('Saved to MelodyPDF folder'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
          if (_isExternalFile)
            IconButton(
              icon: const Icon(Icons.save_alt_rounded, size: 20),
              tooltip: 'Save to app',
              onPressed: _saveToLocal,
            ),
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 20),
            tooltip: 'Share',
            onPressed: _shareFile,
          ),
        ],
      ),
      body: _buildBody(colorScheme),
      bottomNavigationBar: _totalPages > 0
          ? _buildPageIndicator(colorScheme)
          : null,
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              widget.file.isEncrypted ? 'Decrypting...' : 'Loading PDF...',
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

    if (_pdfController == null) {
      return const Center(child: Text('No PDF loaded'));
    }

    return PdfViewPinch(
      controller: _pdfController!,
      onDocumentLoaded: (document) {
        if (mounted) {
          setState(() => _totalPages = document.pagesCount);
        }
      },
      onPageChanged: (page) {
        if (mounted && page != _currentPage) {
          setState(() => _currentPage = page);
          context.read<SettingsProvider>().setLastReadPage(widget.file.path, page);
        }
      },
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(
          loaderSwitchDuration: Duration(milliseconds: 200),
        ),
        documentLoaderBuilder: (context) => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        pageLoaderBuilder: (context) => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        errorBuilder: (context, error) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_rounded, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text('Failed to render page', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _currentPage > 1
                ? () => _pdfController?.animateToPage(
                    pageNumber: _currentPage - 1,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                  )
                : null,
            iconSize: 24,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _currentPage < _totalPages
                ? () => _pdfController?.animateToPage(
                    pageNumber: _currentPage + 1,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                  )
                : null,
            iconSize: 24,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
