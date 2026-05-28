import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'core/audio_handler.dart';
import 'core/cast_service.dart';
import 'app.dart';
import 'screens/splash_screen.dart';

/// Global entry point for the YTMusic Player.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show splash screen immediately
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      theme: ThemeData.dark(),
    ),
  );

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Give some time for splash to show
  await Future.delayed(const Duration(milliseconds: 1500));

  // Initialize Hive
  await _initHive();

  // Initialize the audio service
  final audioHandler = await _initAudioService();

  // Initialize Cast SDK
  final castService = CastService();
  await castService.initialize();

  // Start the real app
  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
        castServiceProvider.overrideWithValue(castService),
      ],
      child: const YTMusicPlayerApp(),
    ),
  );
}

/// Initialize Hive for persistent local storage.
///
/// Stores:
/// - Settings (audio quality, theme, cookies, etc.)
/// - Download manifests (which tracks are saved offline)
/// - Playback history / cache
Future<void> _initHive() async {
  // Use app documents directory for Hive storage
  final appDir = await getApplicationDocumentsDirectory();
  Hive.init(appDir.path);

  // Open essential boxes eagerly
  await Hive.openBox('settings');
  await Hive.openBox('downloads');
  await Hive.openBox('cache');
  await Hive.openBox<String>('search_history');
}

/// Initialize the audio service for background playback.
///
/// Returns the [MusicAudioHandler] instance that manages all audio state.
/// This handler is then provided through Riverpod for the UI to consume.
Future<MusicAudioHandler> _initAudioService() async {
  final handler = await AudioService.init<MusicAudioHandler>(
    builder: () => MusicAudioHandler(),
    config: AudioServiceConfig(
      // Notification channel for Android 13+
      androidNotificationChannelId: 'com.ytmusic.player.music_channel',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationChannelDescription: 'Shows currently playing track',

      // Keep the notification visible while playing
      androidNotificationOngoing: true,

      // Stop service when paused and no media is active
      androidStopForegroundOnPause: true,

      // Notification icon
      androidNotificationIcon: 'mipmap/ic_launcher',

      // Fast-forward skip interval
      fastForwardInterval: const Duration(seconds: 10),
    ),
  );

  return handler;
}
