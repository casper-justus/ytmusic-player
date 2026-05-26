import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

/// Settings screen — account login, audio quality, downloads, theming, casting.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // =============================================================
          //  ACCOUNT
          // =============================================================
          _SectionHeader(title: 'Account'),
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('YouTube Music Login'),
            subtitle: Text(
              settings.cookies != null && settings.cookies!.isNotEmpty
                  ? 'Signed in'
                  : 'Not signed in',
            ),
            trailing: settings.cookies != null && settings.cookies!.isNotEmpty
                ? TextButton(
                    onPressed: () => _confirmLogout(context, notifier),
                    child: const Text('Sign Out'),
                  )
                : null,
            onTap: () => _showCookieDialog(context, notifier),
          ),
          if (settings.cookies != null && settings.cookies!.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Colors.green),
              title: const Text('Account features active'),
              subtitle: const Text('Playlists, library, recommendations'),
              enabled: false,
            ),

          // =============================================================
          //  PLAYBACK
          // =============================================================
          _SectionHeader(title: 'Playback'),
          ListTile(
            leading: const Icon(Icons.quality),
            title: const Text('Audio Quality'),
            subtitle: Text(settings.audioQuality.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showQualityPicker(context, notifier, settings),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.radio),
            title: const Text('Auto-play Radio'),
            subtitle: const Text('Continue with similar songs when queue ends'),
            value: settings.autoPlayRadio,
            onChanged: (v) => notifier.setAutoPlayRadio(v),
          ),

          // =============================================================
          //  DOWNLOADS
          // =============================================================
          _SectionHeader(title: 'Downloads'),
          SwitchListTile(
            secondary: const Icon(Icons.download),
            title: const Text('Enable Downloads'),
            subtitle: const Text('Save tracks for offline playback'),
            value: settings.downloadEnabled,
            onChanged: (v) => notifier.setDownloadEnabled(v),
          ),
          if (settings.downloadEnabled)
            ListTile(
              leading: const Icon(Icons.file_present),
              title: const Text('Download Format'),
              subtitle: Text(settings.downloadFormat.toUpperCase()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showFormatPicker(context, notifier, settings),
            ),

          // =============================================================
          //  LOCAL FILES
          // =============================================================
          _SectionHeader(title: 'Local Files'),
          SwitchListTile(
            secondary: const Icon(Icons.sd_storage),
            title: const Text('Include External Storage'),
            subtitle: const Text('Scan SD card and Music folders'),
            value: settings.includeExternalStorage,
            onChanged: (v) => notifier.setIncludeExternalStorage(v),
          ),

          // =============================================================
          //  THEME
          // =============================================================
          _SectionHeader(title: 'Appearance'),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme'),
            subtitle: Text(settings.themeMode.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemePicker(context, notifier, settings),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.color_lens),
            title: const Text('Dynamic Album Art Theming'),
            subtitle: const Text('UI colors adapt to current track'),
            value: settings.dynamicTheming,
            onChanged: (v) => notifier.setDynamicTheming(v),
          ),

          // =============================================================
          //  CAST
          // =============================================================
          _SectionHeader(title: 'Casting'),
          ListTile(
            leading: const Icon(Icons.cast),
            title: const Text('Default Cast Volume'),
            subtitle: Text('${(settings.castVolume * 100).round()}%'),
            trailing: SizedBox(
              width: 100,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                ),
                child: Slider(
                  value: settings.castVolume,
                  onChanged: (v) => notifier.setCastVolume(v),
                ),
              ),
            ),
          ),

          // =============================================================
          //  ABOUT
          // =============================================================
          _SectionHeader(title: 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('YTMusic Player'),
            subtitle: Text('Version 1.0.0'),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // =======================================================================
  //  Dialogs
  // =======================================================================

  void _showCookieDialog(BuildContext context, SettingsNotifier notifier) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign In'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste your YouTube Music cookies below.\n\n'
              'To get cookies:\n'
              '1. Log in to music.youtube.com\n'
              '2. Open DevTools > Application > Cookies\n'
              '3. Copy all cookies as a semi-colon separated string',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Paste cookies here...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
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
              if (controller.text.trim().isNotEmpty) {
                notifier.setCookies(controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, SettingsNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Clear your YouTube Music sign-in?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              notifier.clearCookies();
              Navigator.pop(ctx);
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showQualityPicker(
      BuildContext context, SettingsNotifier notifier, SettingsState settings) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Audio Quality'),
        children: AudioQuality.values.map((quality) {
          return RadioListTile<AudioQuality>(
            title: Text(quality.label),
            value: quality,
            groupValue: settings.audioQuality,
            onChanged: (v) {
              if (v != null) notifier.setAudioQuality(v);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showFormatPicker(
      BuildContext context, SettingsNotifier notifier, SettingsState settings) {
    const formats = ['m4a', 'mp3', 'opus'];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Download Format'),
        children: formats.map((format) {
          return RadioListTile<String>(
            title: Text(format.toUpperCase()),
            value: format,
            groupValue: settings.downloadFormat,
            onChanged: (v) {
              if (v != null) notifier.setDownloadFormat(v);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showThemePicker(
      BuildContext context, SettingsNotifier notifier, SettingsState settings) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Theme'),
        children: ThemeModeOption.values.map((mode) {
          return RadioListTile<ThemeModeOption>(
            title: Text(mode.label),
            value: mode,
            groupValue: settings.themeMode,
            onChanged: (v) {
              if (v != null) notifier.setThemeMode(v);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
