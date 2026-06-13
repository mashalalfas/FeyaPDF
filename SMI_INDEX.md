# Feya_PDF — SMI Index

## Project Info
- **Name:** Feya PDF
- **Stack:** Flutter/Dart, Android
- **Location:** ~/Development/Feya_PDF/
- **Status:** Active — v1.1
- **Created:** 2026-06-03

## Milestones

### #1 — Initial Build (2026-06-03)
- PDF reader with E2E encryption (AES-256-GCM, .pdf.enc format)
- Tagging system with 8-color palette, filter bar, management screen
- Native Android intent handler for "Open with" support
- Runtime storage permissions for Android 11+ (MANAGE_EXTERNAL_STORAGE)
- Recursive file scanning with Isolate
- Share via share_plus (decrypted for encrypted files)
- Last-read position persistence per file
- flutter analyze: clean
- APK: 52.5MB
- GDrive: https://drive.google.com/open?id=1fwXx8yA-A5K4UfIBb_QZdTjuZsd24bLg

## Architecture
- **Models:** PdfFile, Tag, UserProfile
- **Services:** FileService, EncryptionService, SettingsService, TagService, PermissionService, IntentHandler
- **Providers:** AppState, EncryptionProvider, SettingsProvider, TagProvider
- **Screens:** HomeScreen, ViewerScreen, SettingsScreen, TagsScreen
- **Widgets:** FileListTile, EncryptionBadge, PassphraseDialog, TagChip, TagPickerDialog, LottieRoute

## Design Language
- Teal #00897B primary, amber secondary
- Warm beige #FBF8F1 light bg, dark gray #1A1C1E dark bg
- Material You, Google Fonts Inter
- Hero transitions, stagger animations
- Matches FeyaMD design system exactly

## Dependencies
- flutter, provider, google_fonts, url_launcher, intl
- encrypt, pointycastle (AES-256-GCM encryption)
- shared_preferences (persistence)
- permission_handler, device_info_plus (permissions)
- pdfx (PDF rendering)
- share_plus (file sharing)
- file_picker, path_provider, lottie

## Lessons Learned
- Army protocol: max 2-3 files per soldier, decompose before spawning
- Don't give full builds to single agents — slice by layer
