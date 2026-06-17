import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/app_state.dart';
import 'providers/encryption_provider.dart';
import 'providers/secure_folder_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/tag_provider.dart';
import 'providers/sort_search_provider.dart';
import 'providers/recent_files_provider.dart';
import 'providers/scanned_paths_provider.dart';
import 'providers/file_operations_provider.dart';
import 'services/settings_service.dart';
import 'services/tag_service.dart';
import 'services/intent_handler.dart';
import 'services/highlight_service.dart';
import 'providers/highlight_provider.dart';
import 'theme.dart';
import 'screens/home_screen.dart';
import 'widgets/app_lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final settingsService = SettingsService(prefs);
  await settingsService.migrateLegacyKeys();

  // Storage migration: rename MelodyPDF → FeyaPDF directories
  await _migrateDirectories();
  final tagService = TagService(prefs);
  IntentHandler.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EncryptionProvider()),
        ChangeNotifierProvider(create: (_) => SecureFolderProvider()),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(settingsService),
        ),
        ChangeNotifierProvider(create: (_) => TagProvider(tagService)),
        ChangeNotifierProvider(create: (_) => SortSearchProvider()),
        ChangeNotifierProvider(create: (_) => RecentFilesProvider()),
        ChangeNotifierProvider(create: (_) => ScannedPathsProvider()),
        ChangeNotifierProvider(create: (_) => FileOperationsProvider()),
        ChangeNotifierProvider(
          create: (_) => HighlightProvider(HighlightService(prefs)),
        ),
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const FeyaPdfApp(),
    ),
  );
}

class FeyaPdfApp extends StatefulWidget {
  const FeyaPdfApp({super.key});

  @override
  State<FeyaPdfApp> createState() => _FeyaPdfAppState();
}

class _FeyaPdfAppState extends State<FeyaPdfApp> {
  bool _wired = false;

  @override
  void initState() {
    super.initState();
    // Wire cross-provider dependencies once, after the first frame so
    // Provider context is fully available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_wired && mounted) {
        _wired = true;
        final appState = context.read<AppState>();
        final sortSearch = context.read<SortSearchProvider>();
        final paths = context.read<ScannedPathsProvider>();
        final fileOps = context.read<FileOperationsProvider>();

        appState.attachSortSearch(sortSearch);
        appState.attachScannedPaths(paths);

        fileOps.attachEncryption(context.read<EncryptionProvider>());

        context
            .read<SecureFolderProvider>()
            .attachEncryption(context.read<EncryptionProvider>());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'Feya PDF',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: AppLockGate(child: const HomeScreen()),
    );
  }
}

/// Rename old MelodyPDF directories to FeyaPDF so existing users
/// don't lose their saved files after the rebrand.
Future<void> _migrateDirectories() async {
  final appDir = await getApplicationDocumentsDirectory();

  final oldSaveDir = Directory('${appDir.path}/MelodyPDF');
  final newSaveDir = Directory('${appDir.path}/FeyaPDF');
  if (await oldSaveDir.exists() && !await newSaveDir.exists()) {
    try {
      await oldSaveDir.rename(newSaveDir.path);
    } catch (_) {}
  }

  final oldSecureDir = Directory('${appDir.path}/MelodyPDF_Secure');
  final newSecureDir = Directory('${appDir.path}/FeyaPDF_Secure');
  if (await oldSecureDir.exists() && !await newSecureDir.exists()) {
    try {
      await oldSecureDir.rename(newSecureDir.path);
    } catch (_) {}
  }

  final oldExportDir = Directory('${appDir.path}/MelodyPDF_Exports');
  final newExportDir = Directory('${appDir.path}/FeyaPDF_Exports');
  if (await oldExportDir.exists() && !await newExportDir.exists()) {
    try {
      await oldExportDir.rename(newExportDir.path);
    } catch (_) {}
  }
}
