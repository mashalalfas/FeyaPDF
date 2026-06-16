import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/encryption_provider.dart';

/// Common password patterns that are trivially guessable.
const _commonPasswords = {
  'password', '12345678', '123456789', 'qwertyui', 'qwerty123',
  'admin123', 'letmein1', 'welcome1', 'monkey12', 'dragon12',
  'master12', 'abc12345', 'trustno1', 'sunshine', 'iloveyou',
  'princess', 'football', 'shadow12', 'michael1', 'jordan23',
  'superman', 'batman12', 'starwars', 'feyapdf1', 'melodypd',
};

enum _PassphraseStrength { weak, fair, strong, veryStrong }

_PassphraseStrength _calculateStrength(String passphrase) {
  if (passphrase.isEmpty) return _PassphraseStrength.weak;

  int score = 0;

  // Length scoring
  if (passphrase.length >= 8) score++;
  if (passphrase.length >= 12) score++;
  if (passphrase.length >= 16) score++;

  // Character variety
  if (passphrase.contains(RegExp(r'[a-z]'))) score++;
  if (passphrase.contains(RegExp(r'[A-Z]'))) score++;
  if (passphrase.contains(RegExp(r'[0-9]'))) score++;
  if (passphrase.contains(RegExp(r'[^a-zA-Z0-9]'))) score++;

  // Entropy check: penalize repeated characters
  final uniqueRatio = passphrase.runes.toSet().length / passphrase.length;
  if (uniqueRatio > 0.7) score++;

  if (score <= 3) return _PassphraseStrength.weak;
  if (score <= 5) return _PassphraseStrength.fair;
  if (score <= 7) return _PassphraseStrength.strong;
  return _PassphraseStrength.veryStrong;
}

String _strengthLabel(_PassphraseStrength strength) {
  switch (strength) {
    case _PassphraseStrength.weak:
      return 'Weak';
    case _PassphraseStrength.fair:
      return 'Fair';
    case _PassphraseStrength.strong:
      return 'Strong';
    case _PassphraseStrength.veryStrong:
      return 'Very Strong';
  }
}

Color _strengthColor(_PassphraseStrength strength, ColorScheme cs) {
  switch (strength) {
    case _PassphraseStrength.weak:
      return cs.error;
    case _PassphraseStrength.fair:
      return cs.tertiary;
    case _PassphraseStrength.strong:
      return cs.primary;
    case _PassphraseStrength.veryStrong:
      return Colors.green.shade600;
  }
}

double _strengthFill(_PassphraseStrength strength) {
  switch (strength) {
    case _PassphraseStrength.weak:
      return 0.25;
    case _PassphraseStrength.fair:
      return 0.5;
    case _PassphraseStrength.strong:
      return 0.75;
    case _PassphraseStrength.veryStrong:
      return 1.0;
  }
}

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
          final text = controller.text;
          final strength = _calculateStrength(text);
          final isCommon =
              text.length >= 8 && _commonPasswords.contains(text.toLowerCase());
          final isValid = text.length >= 8 && !isCommon;
          final colorScheme = Theme.of(ctx).colorScheme;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.lock_rounded,
                  color: colorScheme.primary,
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
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  obscureText: obscure,
                  onChanged: (_) => setDialogState(() {}),
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
                    if (isValid) {
                      Navigator.pop(ctx, true);
                    }
                  },
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Strength meter bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: _strengthFill(strength),
                      ),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      builder: (_, value, child) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          backgroundColor:
                              colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(
                            _strengthColor(strength, colorScheme),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        strength == _PassphraseStrength.weak
                            ? Icons.warning_amber_rounded
                            : strength == _PassphraseStrength.veryStrong
                                ? Icons.verified_rounded
                                : Icons.check_circle_outline_rounded,
                        size: 16,
                        color: _strengthColor(strength, colorScheme),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _strengthLabel(strength),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _strengthColor(strength, colorScheme),
                        ),
                      ),
                      if (isCommon) ...[
                        const Spacer(),
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Common password',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                if (text.isNotEmpty && text.length < 8) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Minimum 8 characters required',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.error,
                    ),
                  ),
                ],
                if (isCommon) ...[
                  const SizedBox(height: 6),
                  Text(
                    'This is a commonly used password. Please choose a stronger one.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '⚠️ If you forget this, encrypted PDFs cannot be recovered.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.error,
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
                onPressed: isValid
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
