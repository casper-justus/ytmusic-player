import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// =======================================================================
//  Settings State
// =======================================================================

class SettingsState {
  /// YouTube Music cookies for authenticated features.
  final String? cookies;

  /// Audio quality preference.
  final AudioQuality audioQuality;

  /// Whether to download using yt-dlp or just cache streams.
  final bool downloadEnabled;

  /// Download format preference.
  final String downloadFormat;

  /// Whether to include external storage in local media scan.
  final bool includeExternalStorage;

  /// Theme mode.
  final ThemeModeOption themeMode;

  /// Whether dynamic album art theming is enabled.
  final bool dynamicTheming;

  /// Whether to auto-play related songs when queue ends.
  final bool autoPlayRadio;

  /// Cast volume (0.0 - 1.0).
  final double castVolume;

  /// Max number of search results.
  final int maxSearchResults;

  const SettingsState({
    this.cookies,
    this.audioQuality = AudioQuality.auto,
    this.downloadEnabled = true,
    this.downloadFormat = 'm4a',
    this.includeExternalStorage = false,
    this.themeMode = ThemeModeOption.system,
    this.dynamicTheming = true,
    this.autoPlayRadio = true,
    this.castVolume = 1.0,
    this.maxSearchResults = 20,
  });

  SettingsState copyWith({
    String? cookies,
    AudioQuality? audioQuality,
    bool? downloadEnabled,
    String? downloadFormat,
    bool? includeExternalStorage,
    ThemeModeOption? themeMode,
    bool? dynamicTheming,
    bool? autoPlayRadio,
    double? castVolume,
    int? maxSearchResults,
    bool clearCookies = false,
  }) {
    return SettingsState(
      cookies: clearCookies ? null : (cookies ?? this.cookies),
      audioQuality: audioQuality ?? this.audioQuality,
      downloadEnabled: downloadEnabled ?? this.downloadEnabled,
      downloadFormat: downloadFormat ?? this.downloadFormat,
      includeExternalStorage: includeExternalStorage ?? this.includeExternalStorage,
      themeMode: themeMode ?? this.themeMode,
      dynamicTheming: dynamicTheming ?? this.dynamicTheming,
      autoPlayRadio: autoPlayRadio ?? this.autoPlayRadio,
      castVolume: castVolume ?? this.castVolume,
      maxSearchResults: maxSearchResults ?? this.maxSearchResults,
    );
  }
}

// =======================================================================
//  Enums
// =======================================================================

enum AudioQuality {
  auto('Auto'),
  low('Low (48kbps)'),
  medium('Medium (128kbps)'),
  high('High (256kbps)'),
  lossless('Lossless');

  final String label;
  const AudioQuality(this.label);
}

enum ThemeModeOption {
  system('System'),
  light('Light'),
  dark('Dark'),
  black('AMOLED Black');

  final String label;
  const ThemeModeOption(this.label);
}

// =======================================================================
//  Settings Notifier
// =======================================================================

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  void setCookies(String cookies) {
    state = state.copyWith(cookies: cookies);
  }

  void clearCookies() {
    state = state.copyWith(clearCookies: true);
  }

  void setAudioQuality(AudioQuality quality) {
    state = state.copyWith(audioQuality: quality);
  }

  void setDownloadEnabled(bool enabled) {
    state = state.copyWith(downloadEnabled: enabled);
  }

  void setDownloadFormat(String format) {
    state = state.copyWith(downloadFormat: format);
  }

  void setIncludeExternalStorage(bool include) {
    state = state.copyWith(includeExternalStorage: include);
  }

  void setThemeMode(ThemeModeOption mode) {
    state = state.copyWith(themeMode: mode);
  }

  void setDynamicTheming(bool enabled) {
    state = state.copyWith(dynamicTheming: enabled);
  }

  void setAutoPlayRadio(bool enabled) {
    state = state.copyWith(autoPlayRadio: enabled);
  }

  void setCastVolume(double volume) {
    state = state.copyWith(castVolume: volume.clamp(0.0, 1.0));
  }

  void setMaxSearchResults(int count) {
    state = state.copyWith(maxSearchResults: count.clamp(5, 100));
  }

  /// Validate and maybe save cookies to secure storage.
  Future<bool> validateAndSaveCookies(String cookies) async {
    try {
      // In production, validate cookies with YT Music API
      setCookies(cookies);
      return true;
    } catch (e) {
      return false;
    }
  }
}

// =======================================================================
//  Providers
// =======================================================================

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
