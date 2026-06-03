import 'package:flutter/material.dart';
import '../models/pdf_file.dart';
import '../models/tag.dart';
import 'tag_chip.dart';

class FileListTile extends StatelessWidget {
  final PdfFile file;
  final List<Tag> tags;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onEncrypt;
  final VoidCallback? onTag;

  const FileListTile({
    super.key,
    required this.file,
    this.tags = const [],
    required this.isSelected,
    required this.onTap,
    this.onDelete,
    this.onShare,
    this.onEncrypt,
    this.onTag,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          onLongPress: () => _showContextMenu(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Hero(
                  tag: 'file-icon-${file.path}',
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSelected ? Icons.picture_as_pdf_rounded : Icons.description_outlined,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.displayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            file.modifiedFormatted,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.data_usage_rounded,
                            size: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            file.sizeFormatted,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _TagRow(tags: tags),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                file.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(),
            if (onShare != null)
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(ctx);
                  onShare?.call();
                },
              ),
            if (onEncrypt != null && !file.isEncrypted)
              ListTile(
                leading: Icon(
                  Icons.lock_outline_rounded,
                  color: Theme.of(ctx).colorScheme.tertiary,
                ),
                title: const Text('Encrypt'),
                onTap: () {
                  Navigator.pop(ctx);
                  onEncrypt?.call();
                },
              ),
            ListTile(
              leading: Icon(
                Icons.label_outline_rounded,
                color: Theme.of(ctx).colorScheme.primary,
              ),
              title: const Text('Tag'),
              trailing: tags.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _TagDotsRow(tags: tags, max: 3),
                    ),
              onTap: () {
                Navigator.pop(ctx);
                onTag?.call();
              },
            ),
            if (onDelete != null)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
                title: Text('Delete', style: TextStyle(color: Colors.red.shade400)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete file?'),
        content: Text('Permanently delete "${file.name}"?\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Inline row of colored tag dots, with overflow handling.
class _TagRow extends StatelessWidget {
  final List<Tag> tags;
  const _TagRow({required this.tags});

  static const int _maxVisible = 4;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant =
        Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.55);
    final visible = tags.length > _maxVisible
        ? tags.sublist(0, _maxVisible - 1)
        : tags;
    final hiddenCount = tags.length - visible.length;

    return Row(
      children: [
        for (final tag in visible) ...[
          TagDot(tag: tag, size: 7),
          const SizedBox(width: 4),
        ],
        if (hiddenCount > 0) ...[
          Text(
            '+$hiddenCount',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Variant of the dots row used in the context menu.
class _TagDotsRow extends StatelessWidget {
  final List<Tag> tags;
  final int max;
  const _TagDotsRow({required this.tags, this.max = 3});

  @override
  Widget build(BuildContext context) {
    final visible = tags.length > max ? tags.sublist(0, max) : tags;
    final hidden = tags.length - visible.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tag in visible) ...[
          TagDot(tag: tag, size: 8),
          const SizedBox(width: 4),
        ],
        if (hidden > 0)
          Text(
            '+$hidden',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
