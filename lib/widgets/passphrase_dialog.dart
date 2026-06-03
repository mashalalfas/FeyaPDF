import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/encryption_provider.dart';

/// Shows a dialog to set/view/change the session passphrase.
/// Returns true if passphrase was set, false if cancelled.
Future<bool> showPassphraseDialog(BuildContext context) async {
  final controller = TextEditingController();
  bool obscure = true;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.lock_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                const Text('Session Passphrase'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Used to encrypt/decrypt PDFs. '
                  'Not stored on disk — only held in memory.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    hintText: 'Enter passphrase',
                    prefixIcon: const Icon(Icons.vpn_key_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20,
                      ),
                      onPressed: () =>
                          setDialogState(() => obscure = !obscure),
                    ),
                  ),
                  onSubmitted: (_) {
                    if (controller.text.isNotEmpty) {
                      Navigator.pop(ctx, true);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '⚠️ If you forget this, encrypted PDFs cannot be recovered.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: controller.text.isNotEmpty
                    ? () => Navigator.pop(ctx, true)
                    : null,
                child: const Text('Set'),
              ),
            ],
          );
        },
      );
    },
  );

  if (result == true && controller.text.isNotEmpty) {
    if (context.mounted) {
      context.read<EncryptionProvider>().setPassphrase(controller.text);
    }
    controller.dispose();
    return true;
  }
  controller.dispose();
  return false;
}
