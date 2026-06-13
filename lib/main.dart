import 'package:flutter/material.dart';
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
import 'theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final settingsService = SettingsService(prefs);
  await settingsService.migrateLegacyKeys();
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
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const MelodyPdfApp(),
    ),
  );
}

class MelodyPdfApp extends StatefulWidget {
  const MelodyPdfApp({super.key});

  @override
  State<MelodyPdfApp> createState() => _MelodyPdfAppState();
}

class _MelodyPdfAppState extends State<MelodyPdfApp> {
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
      title: 'Melody PDF',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: const HomeScreen(),
    );
  }
}
