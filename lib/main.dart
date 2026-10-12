import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/theme/app_theme.dart';
import 'features/home/main_navigation_screen.dart';
import 'features/desktop/desktop_main_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/settings/controllers/settings_controller.dart';
import 'services/audio_handler.dart';
import 'services/youtube_service.dart';
import 'services/auth_service.dart';
import 'services/history_service.dart';
import 'services/device_playback_sync_service.dart';
import 'models/isar_models.dart';
import 'services/update_service.dart';
import 'models/app_update_info.dart';
import 'common_widgets/update_dialog.dart';

late MozeAudioHandler audioHandler;
late Isar isar;
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
bool _hasShownUpdateDialogThisSession = false;

bool get isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop window setup
  if (isDesktop) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(960, 600),
      center: true,
      title: 'MozeMusic',
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Isar
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [HistoryEntrySchema, DownloadEntrySchema, SearchQueryEntrySchema],
      directory: dir.path,
    );

    // Initialize AudioService
    final youtubeService = YoutubeService();
    final prefs = await SharedPreferences.getInstance();
    final historyService = HistoryService(isar);

    audioHandler = await AudioService.init(
      builder: () => MozeAudioHandler(youtubeService, prefs, historyService),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.mozemusic.channel.audio',
        androidNotificationChannelName: 'MozeMusic Playback',
        androidNotificationChannelDescription: 'MozeMusic background playback controls and notification',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
        androidShowNotificationBadge: !isDesktop,
        androidNotificationIcon: 'mipmap/launcher_icon',
        androidNotificationClickStartsActivity: true,
      ),
    );

    runApp(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(audioHandler),
          youtubeServiceProvider.overrideWithValue(youtubeService),
          sharedPrefsProvider.overrideWithValue(prefs),
        ],
        child: const MozeMusicApp(),
      ),
    );
  } catch (e, st) {
    debugPrint('Initialization error: $e');
    debugPrint('Stack trace: $st');
    stderr.writeln('FATAL: $e\n$st');
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                  const SizedBox(height: 16),
                  const Text('Oops! Something went wrong.', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Please check your connection and restart the app.', style: TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MozeMusicApp extends ConsumerWidget {
  const MozeMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    ref.watch(devicePlaybackSyncServiceProvider);

    // Live update broadcast listener: triggers when admin pushes a new update
    ref.listen<AsyncValue<AppUpdateInfo?>>(updateStreamProvider, (prev, next) {
      final info = next.value;
      if (info != null && UpdateService.isNewerVersion(UpdateService.currentVersion, info.latestVersion)) {
        if (!_hasShownUpdateDialogThisSession || info.forceUpdate) {
          _hasShownUpdateDialogThisSession = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final navContext = rootNavigatorKey.currentContext;
            if (navContext != null) {
              UpdateDialog.show(navContext, info);
            }
          });
        }
      }
    });

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'MozeMusic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          return isDesktop
              ? const DesktopMainScreen()
              : const MainNavigationScreen();
        }
        return const LoginScreen();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

