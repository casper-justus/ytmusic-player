import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/track.dart';

/// Service that extracts audio stream URLs using yt-dlp.
///
/// Uses the `extractor` Flutter plugin which bundles youtubedl-android
/// (yt-dlp + Python 3.8 + FFmpeg 6.0) natively in the APK.
///
/// On first call, the native binaries are extracted to the app's internal
/// storage. Subsequent calls reuse them. This means the first extraction
/// may take a few seconds longer.
class YtdlpService {
  static final YtdlpService _instance = YtdlpService._();
  factory YtdlpService() => _instance;
  YtdlpService._();

  bool _initialized = false;

  /// Initialize the yt-dlp native backend.
  /// Must be called once before any extraction. Called automatically on first use.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      // The extractor plugin handles binary extraction internally.
      // We just need to ensure the platform channel is ready.
      await _invokeMethod('initialize');
      _initialized = true;
    } catch (e) {
      // Fallback: try downloading yt-dlp if not bundled
      await _invokeMethod('downloadYtDlp');
      _initialized = true;
    }
  }

  /// Extract the best audio stream URL for a YouTube/YT Music video.
  ///
  /// Returns the direct audio stream URL that can be fed to just_audio.
  /// The [videoUrl] can be any YouTube or YouTube Music URL format:
  ///   - https://music.youtube.com/watch?v=...
  ///   - https://www.youtube.com/watch?v=...
  ///   - https://youtu.be/...
  ///   - Just the video ID as a convenience.
  Future<String?> getAudioStreamUrl(String videoUrl) async {
    await initialize();

    final resolvedUrl = _resolveUrl(videoUrl);
    final result = await _invokeMethod('getVideoInfo', {'url': resolvedUrl});

    if (result == null) return null;

    final data = jsonDecode(result) as Map<String, dynamic>;

    // Prefer audio-only formats (opus, m4a, webm)
    final audioFormats = <Map<String, dynamic>>[];

    if (data['audio_only_formats'] != null) {
      audioFormats.addAll(
        List<Map<String, dynamic>>.from(data['audio_only_formats'] as List),
      );
    }
    if (data['raw_audio_only_formats'] != null) {
      audioFormats.addAll(
        List<Map<String, dynamic>>.from(data['raw_audio_only_formats'] as List),
      );
    }

    if (audioFormats.isEmpty) return null;

    // Sort by bitrate descending, pick the best
    audioFormats.sort((a, b) {
      final aBitrate = (a['bitrate'] ?? a['abr'] ?? 0) as num;
      final bBitrate = (b['bitrate'] ?? b['abr'] ?? 0) as num;
      return bBitrate.compareTo(aBitrate);
    });

    return audioFormats.first['url'] as String?;
  }

  /// Extract full metadata for a video, including available formats.
  Future<Map<String, dynamic>?> getVideoInfo(String videoUrl) async {
    await initialize();

    final resolvedUrl = _resolveUrl(videoUrl);
    final result = await _invokeMethod('getVideoInfo', {'url': resolvedUrl});

    if (result == null) return null;
    return jsonDecode(result) as Map<String, dynamic>;
  }

  /// Download a video's audio to the given [outputPath].
  ///
  /// Returns the path to the downloaded file on success, null on failure.
  /// The [format] can be 'mp3', 'm4a', 'opus', or 'best'.
  Future<String?> downloadAudio({
    required String videoUrl,
    required String outputPath,
    String format = 'best',
  }) async {
    await initialize();

    final resolvedUrl = _resolveUrl(videoUrl);
    final result = await _invokeMethod('downloadAudio', {
      'url': resolvedUrl,
      'outputPath': outputPath,
      'format': format,
    });

    if (result == null) return null;
    return result as String?;
  }

  /// Get download progress stream (0.0 to 1.0).
  /// The [downloadId] is returned by [downloadAudio].
  Stream<double> getDownloadProgress(String downloadId) {
    // The extractor plugin should emit progress events.
    // This is a placeholder for the actual implementation.
    return const Stream.empty();
  }

  /// Extract metadata into a [Track] model.
  Future<Track?> extractTrack(String videoUrl) async {
    final info = await getVideoInfo(videoUrl);
    if (info == null) return null;

    final videoId = info['id'] as String? ?? '';
    final title = info['title'] as String? ?? 'Unknown';
    final artist = _extractArtist(info);
    final album = info['album'] as String?;
    final albumArtUrl = _extractThumbnail(info);
    final durationMs = info['duration'] as int? ?? 0;

    return Track(
      id: videoId,
      videoId: videoId,
      title: title,
      artist: artist,
      album: album,
      albumArtUrl: albumArtUrl,
      duration: Duration(milliseconds: durationMs * 1000),
    );
  }

  // ---- Private helpers ----

  String _resolveUrl(String input) {
    if (input.startsWith('http://') || input.startsWith('https://')) {
      return input;
    }
    // Assume it's a video ID
    return 'https://music.youtube.com/watch?v=$input';
  }

  String _extractArtist(Map<String, dynamic> info) {
    // Try multiple fields that yt-dlp may use for artist
    final artist = info['artist'] as String?;
    if (artist != null && artist.isNotEmpty) return artist;

    final uploader = info['uploader'] as String?;
    if (uploader != null && uploader.isNotEmpty) return uploader;

    final channel = info['channel'] as String?;
    if (channel != null && channel.isNotEmpty) return channel;

    // Try the first artist from 'artists' list
    final artists = info['artists'] as List?;
    if (artists != null && artists.isNotEmpty) {
      final first = artists.first;
      if (first is String) return first;
      if (first is Map) return first['name'] as String? ?? 'Unknown Artist';
    }

    return 'Unknown Artist';
  }

  String? _extractThumbnail(Map<String, dynamic> info) {
    final thumbnails = info['thumbnails'] as List?;
    if (thumbnails == null || thumbnails.isEmpty) return null;

    // Pick the highest resolution thumbnail
    thumbnails.sort((a, b) {
      final aRes = ((a as Map)['height'] ?? 0) as int;
      final bRes = ((b as Map)['height'] ?? 0) as int;
      return bRes.compareTo(aRes);
    });

    return (thumbnails.first as Map)['url'] as String?;
  }

  /// Invoke a method on the extractor platform channel.
  Future<dynamic> _invokeMethod(String method, [Map<String, dynamic>? args]) async {
    try {
      return await MethodChannel('com.ytmusic.player/extractor')
          .invokeMethod(method, args);
    } on MissingPluginException {
      // Fallback for environment without the native plugin
      return _devFallback(method, args);
    }
  }

  /// Development fallback when running without native plugin.
  /// Returns mock data so UI can be developed without yt-dlp.
  Future<dynamic> _devFallback(String method, Map<String, dynamic>? args) async {
    if (method == 'getVideoInfo') {
      return jsonEncode({
        'id': 'dQw4w9WgXcQ',
        'title': 'Rick Astley - Never Gonna Give You Up',
        'artist': 'Rick Astley',
        'album': 'Whenever You Need Somebody',
        'duration': 212,
        'thumbnails': [
          {'url': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg', 'height': 720},
        ],
        'audio_only_formats': [
          {
            'url': 'https://example.com/stream.m4a',
            'bitrate': 128,
            'abr': 128,
          },
        ],
      });
    }
    if (method == 'initialize' || method == 'downloadYtDlp') return true;
    return null;
  }
}
