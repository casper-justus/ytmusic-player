import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'core/audio_handler.dart';
import 'app.dart';

/// Global entry point for the YTMusic Player.
///
/// Initialization order:
/// 1. WidgetsFlutterBinding (Flutter engine)
/// 2. Hive (local storage for settings, cache)
/// 3. AudioService (background playback + media notifications)
/// 4. Run the Riverpod-wrapped app
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait — music player UI doesn't benefit from landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Hive for local storage
  await _initHive();

  // Initialize the audio service (background playback, notifications)
  final audioHandler = await _initAudioService();

  // Start the app
  runApp(
    ProviderScope(
      overrides: [
        // Provide the audio handler globally so Riverpod can inject it
        audioHandlerProvider.overrideWithValue(audioHandler),
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
}

/// Initialize the audio service for background playback.
///
/// Returns the [MusicAudioHandler] instance that manages all audio state.
/// This handler is then provided through Riverpod for the UI to consume.
Future<MusicAudioHandler> _initAudioService() async {
  final handler = await AudioService.init<MusicAudioHandler>(
    builder: () => MusicAudioHandler(),
    config: const AudioServiceConfig(
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

      // Fast-forward/rewind skip interval
      fastForwardInterval: const Duration(seconds: 10),
      seekBackwardInterval: const Duration(seconds: 10),
    ),
  );

  return handler;
}
