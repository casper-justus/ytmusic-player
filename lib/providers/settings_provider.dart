import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
//  Settings State
// =======================================================================

class SettingsState {
  final String? cookies;
  final AudioQuality audioQuality;
  final bool downloadEnabled;
  final String downloadFormat;
  final bool includeExternalStorage;
  final ThemeModeOption themeMode;
  final bool dynamicTheming;
  final bool autoPlayRadio;
  final double castVolume;
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
//  Settings Notifier
// =======================================================================

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _loadFromHive();
  }

  void _loadFromHive() {
    final box = Hive.box('settings');
    state = SettingsState(
      cookies: box.get('cookies') as String?,
      audioQuality: AudioQuality.values.firstWhere(
        (v) => v.name == box.get('audioQuality'),
        orElse: () => AudioQuality.auto,
      ),
      downloadEnabled: box.get('downloadEnabled', defaultValue: true) as bool,
      downloadFormat: box.get('downloadFormat', defaultValue: 'm4a') as String,
      includeExternalStorage: box.get('includeExternalStorage', defaultValue: false) as bool,
      themeMode: ThemeModeOption.values.firstWhere(
        (v) => v.name == box.get('themeMode'),
        orElse: () => ThemeModeOption.system,
      ),
      dynamicTheming: box.get('dynamicTheming', defaultValue: true) as bool,
      autoPlayRadio: box.get('autoPlayRadio', defaultValue: true) as bool,
      castVolume: box.get('castVolume', defaultValue: 1.0) as double,
      maxSearchResults: box.get('maxSearchResults', defaultValue: 20) as int,
    );
  }

  void _saveToHive(String key, dynamic value) {
    Hive.box('settings').put(key, value);
  }

  void setCookies(String cookies) {
    state = state.copyWith(cookies: cookies);
    _saveToHive('cookies', cookies);
  }

  void clearCookies() {
    state = state.copyWith(clearCookies: true);
    _saveToHive('cookies', null);
  }

  void setAudioQuality(AudioQuality quality) {
    state = state.copyWith(audioQuality: quality);
    _saveToHive('audioQuality', quality.name);
  }

  void setDownloadEnabled(bool enabled) {
    state = state.copyWith(downloadEnabled: enabled);
    _saveToHive('downloadEnabled', enabled);
  }

  void setDownloadFormat(String format) {
    state = state.copyWith(downloadFormat: format);
    _saveToHive('downloadFormat', format);
  }

  void setIncludeExternalStorage(bool include) {
    state = state.copyWith(includeExternalStorage: include);
    _saveToHive('includeExternalStorage', include);
  }

  void setThemeMode(ThemeModeOption mode) {
    state = state.copyWith(themeMode: mode);
    _saveToHive('themeMode', mode.name);
  }

  void setDynamicTheming(bool enabled) {
    state = state.copyWith(dynamicTheming: enabled);
    _saveToHive('dynamicTheming', enabled);
  }

  void setAutoPlayRadio(bool enabled) {
    state = state.copyWith(autoPlayRadio: enabled);
    _saveToHive('autoPlayRadio', enabled);
  }

  void setCastVolume(double volume) {
    state = state.copyWith(castVolume: volume.clamp(0.0, 1.0));
    _saveToHive('castVolume', state.castVolume);
  }

  void setMaxSearchResults(int count) {
    state = state.copyWith(maxSearchResults: count.clamp(5, 100));
    _saveToHive('maxSearchResults', state.maxSearchResults);
  }

  Future<bool> validateAndSaveCookies(String cookies) async {
    try {
      setCookies(cookies);
      return true;
    } catch (e) {
      return false;
    }
  }
}

// =======================================================================
//  Provider
// =======================================================================

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
