import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/encryption_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/passphrase_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final encryption = context.watch<EncryptionProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Account Section ──
          _SectionHeader('Account'),
          ListTile(
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                settings.userProfile.name.isNotEmpty
                    ? settings.userProfile.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 20,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            title: Text(
              settings.userProfile.name.isEmpty
                  ? 'Set your name'
                  : settings.userProfile.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              settings.userProfile.email.isEmpty
                  ? 'Tap to edit profile'
                  : settings.userProfile.email,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showEditProfileDialog(context, settings),
          ),

          const SizedBox(height: 8),

          // ── Encryption Section ──
          _SectionHeader('Encryption'),
          ListTile(
            leading: const Icon(Icons.key_rounded),
            title: const Text('Passphrase'),
            subtitle: Text(
              encryption.hasPassphrase
                  ? '●●●●●●●●'
                  : 'Not set — files will not be encrypted',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showPassphraseDialog(context),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline_rounded),
            title: const Text('Auto-encrypt new files'),
            subtitle: Text(
              'New PDF files are encrypted on import',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            value: settings.autoEncrypt,
            onChanged: (v) => settings.setAutoEncrypt(v),
          ),
          if (encryption.hasPassphrase)
            ListTile(
              leading: Icon(Icons.lock_open_rounded, color: colorScheme.error),
              title: Text(
                'Clear passphrase',
                style: TextStyle(color: colorScheme.error),
              ),
              subtitle: Text(
                'Lock all encrypted files until re-entered',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              onTap: () {
                encryption.clearPassphrase();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Passphrase cleared'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
            ),

          const SizedBox(height: 8),

          // ── Appearance Section ──
          _SectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            subtitle: Text(
              _themeModeLabel(settings.themeMode),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showThemePicker(context, settings),
          ),

          const SizedBox(height: 8),

          // ── About Section ──
          _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Version'),
            trailing: Text(
              '1.0.0+1',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.code_rounded),
            title: const Text('Open source licenses'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Melody PDF',
              applicationVersion: '1.0.0+1',
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  void _showThemePicker(BuildContext context, SettingsProvider settings) {
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
                color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                'Theme',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            _themeOption(ctx, settings, ThemeMode.system, Icons.brightness_auto_rounded, 'System'),
            _themeOption(ctx, settings, ThemeMode.light, Icons.light_mode_rounded, 'Light'),
            _themeOption(ctx, settings, ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(
    BuildContext context,
    SettingsProvider settings,
    ThemeMode mode,
    IconData icon,
    String label,
  ) {
    final isActive = settings.themeMode == mode;
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: isActive ? colorScheme.primary : null),
      title: Text(label),
      trailing: isActive
          ? Icon(Icons.check_rounded, color: colorScheme.primary)
          : null,
      onTap: () {
        settings.setThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  void _showEditProfileDialog(BuildContext context, SettingsProvider settings) {
    final nameController = TextEditingController(text: settings.userProfile.name);
    final emailController = TextEditingController(text: settings.userProfile.email);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              settings.updateUserProfile(
                settings.userProfile.copyWith(
                  name: nameController.text,
                  email: emailController.text,
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
