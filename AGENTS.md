# YTMusic Player — Agent Guidance

## Build & Analyze

```sh
# Resolve dependencies
flutter pub get

# Analyze only project code (avoids 771k Flutter SDK false errors)
dart analyze lib/

# Build debug APK (requires Android SDK + platform 34 + build-tools 34.0.0)
flutter build apk --debug

# Full flutter doctor — Android toolchain should show SDK 34.0.0
flutter doctor
```

Always run `dart analyze lib/` (never `flutter analyze` alone — it scans the Flutter SDK tree and produces 771k false errors from `integration_test`).

## Architecture

- **State management**: Riverpod `StateNotifierProvider` — `PlayerNotifier`, `SettingsNotifier`, `LibraryNotifier`. Providers in `lib/providers/`.
- **Background audio**: `audio_service` with `MusicAudioHandler` (`BaseAudioHandler` + `QueueHandler` + `SeekHandler` mixins) in `lib/core/audio_handler.dart`.
- **Stream extraction**: `YtdlpService` in `lib/core/ytdlp_service.dart` wraps the `extractor` Flutter plugin (bundles youtubedl-android natively). Has a `_devFallback()` that returns mock data when the native plugin is absent — useful for UI development without a device.
- **YT Music API**: `YtMusicService` in `lib/core/ytmusic_service.dart` wraps `dart_ytmusic_api` v1.3.6. Does NOT have `getLibraryPlaylists()`, `getLikedSongs()`, or `getMix()` — these library features are unavailable in this version.
- **Dynamic theming**: `PlayerState` holds `dominantColor`/`vibrantColor` from `palette_generator`, set via `PlayerNotifier.setAlbumColors()`.
- **Entrypoints**: `lib/main.dart` → Hive init → `AudioService.init<MusicAudioHandler>()` → `runApp(ProviderScope(...))` → `lib/app.dart` (`YTMusicPlayerApp` → `MainShell` with 4-tab `IndexedStack`).

## Riverpod Wiring

```dart
// audioHandlerProvider — overridden in main.dart with the real AudioService instance
final audioHandlerProvider = Provider<MusicAudioHandler>(...)

// playerStateProvider depends on audioHandlerProvider + ytdlpServiceProvider
final playerStateProvider = StateNotifierProvider<PlayerNotifier, PlayerState>(...)

// Convenience selectors
final currentTrackProvider = Provider<Track?>(...)
final isPlayingProvider = Provider<bool>(...)
final queueProvider = Provider<List<Track>>(...)
final isLoadingProvider = Provider<bool>(...)

// settingsProvider — standalone, no deps
// ytdlpServiceProvider — standalone singleton
```

## Android Config

- `minSdk 24`, `compileSdk 34`, `targetSdk 34`
- `android:extractNativeLibs="true"` (required for yt-dlp native binaries)
- `multiDexEnabled true` (app has 145+ dependencies)
- `namespace "com.ytmusic.player"`, `applicationId "com.ytmusic.player"`
- Google Cast SDK 21.2.0, Media3 ExoPlayer 1.2.1
- AudioService notification channel: `com.ytmusic.player.music_channel`
- Permissions: INTERNET, FOREGROUND_SERVICE_MEDIA_PLAYBACK, POST_NOTIFICATIONS, BLUETOOTH_CONNECT, storage (up to SDK 32), Chromecast (ACCESS_FINE_LOCATION, WIFI_STATE)

## Coding Conventions

- **Imports**: Prefer relative paths (`'../core/audio_handler.dart'`). Use `dart:ui` for `Color` (not `flutter/material.dart`).
- **Constructors**: Use `const` where possible. Lint enforces `prefer_const_constructors` and `prefer_const_declarations`.
- **Strings**: Prefer single quotes (`prefer_single_quotes` linter rule).
- **Keys**: Widget constructors should accept `super.key`.
- **Prints**: `avoid_print: false` — debug prints are allowed.
- **Riverpod**: `ref.onDispose(() => notifier.dispose())` pattern in providers that create StateNotifiers.

## Known Gotchas

- `AudioServiceConfig` has **no** `seekBackwardInterval` parameter (only `fastForwardInterval`).
- `BaseAudioHandler.repeatMode` is accessed via `playbackState.valueOrNull?.repeatMode` (not a direct property).
- `AudioPlayer.durationStream` returns `Stream<Duration?>` (nullable).
- `just_audio` `AudioSource.file()` and `AudioSource.uri()` expect non-null arguments — call `setAudioSource(null)` is invalid. Use guard before setting.
- `permission_handler` locked to `^12.0.1` — required by `flutter_chrome_cast ^1.4.6`. Cannot upgrade independently.
- `Icons.quality` does not exist in Material Icons. Use `Icons.music_note` or similar.
- `YtdlpService._invokeMethod` uses `MethodChannel('com.ytmusic.player/extractor')` — this only works on Android.

## Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | Entry, Hive init, AudioService init, ProviderScope |
| `lib/app.dart` | MaterialApp, M3 theming, AMOLED support, 4-tab MainShell, route gen |
| `lib/core/audio_handler.dart` | MusicAudioHandler with QueueHandler/SeekHandler, audioHandlerProvider |
| `lib/core/ytdlp_service.dart` | Stream URL extraction via extractor plugin, dev fallback |
| `lib/core/ytmusic_service.dart` | YT Music API wrapper (limited to v1.3.6 features) |
| `lib/providers/player_provider.dart` | PlayerNotifier, playerStateProvider, convenience selectors |
| `lib/providers/settings_provider.dart` | SettingsNotifier, AudioQuality/ThemeModeOption enums |
| `lib/providers/library_provider.dart` | LibraryNotifier (home/search/library tabs) |
| `lib/models/track.dart` | Track data class with copyWith, toJson, fromJson |
| `lib/screens/player_screen.dart` | Full Now Playing screen with dynamic gradient |
| `lib/screens/settings_screen.dart` | Cookie login, quality, theme, cast volume |
| `android/app/build.gradle` | Android config (minSdk 24, compileSdk 34, Cast SDK, Media3) |
| `pubspec.yaml` | All dependencies (145 total), assets |

## Dev Environment (Codespace)

- Flutter 3.29.2 installed at `/home/codespace/flutter/bin/flutter`
- Android SDK at `/usr/local/lib/android/sdk`
- Update files via `gh codespace cp -e <local> remote:<path> -c <codespace-name>`
- The `--directory` flag does NOT exist for `flutter build` — use `cd <project>` then build
