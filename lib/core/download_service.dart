import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import 'ytdlp_service.dart';

/// Manages downloading tracks for offline playback.
///
/// Downloads are stored in the app's documents directory under `downloads/`.
/// Each download is tracked with progress, and the service persists
/// a manifest of downloaded tracks.
class DownloadService {
  final YtdlpService _ytdlp = YtdlpService();
  final Dio _dio = Dio();

  /// Map of active downloads: videoId -> progress (0.0 to 1.0)
  final Map<String, double> _activeDownloads = {};

  /// Set of completed download videoIds.
  final Set<String> _completedDownloads = {};

  /// Directory where downloads are stored.
  String? _downloadDir;

  /// Initialize the download directory.
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _downloadDir = '${appDir.path}/downloads';
    final dir = Directory(_downloadDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Scan existing downloads
    await _scanExistingDownloads();
  }

  /// Scan the downloads directory for previously downloaded files.
  Future<void> _scanExistingDownloads() async {
    if (_downloadDir == null) return;
    final dir = Directory(_downloadDir!);
    if (!await dir.exists()) return;

    await for (final file in dir.list()) {
      if (file is File && file.path.endsWith('.m4a') || file.path.endsWith('.mp3') || file.path.endsWith('.opus')) {
        // Extract video ID from filename: {videoId}.{ext}
        final filename = file.uri.pathSegments.last;
        final videoId = filename.split('.').first;
        _completedDownloads.add(videoId);
      }
    }
  }

  /// Check if a track is already downloaded.
  bool isDownloaded(Track track) => _completedDownloads.contains(track.videoId);

  /// Get the local file path for a downloaded track, if it exists.
  Future<String?> getLocalPath(Track track) async {
    if (_downloadDir == null) return null;
    for (final ext in ['m4a', 'mp3', 'opus']) {
      final file = File('$_downloadDir/${track.videoId}.$ext');
      if (await file.exists()) return file.path;
    }
    return null;
  }

  /// Download a track's audio for offline playback.
  ///
  /// Returns a stream of download progress (0.0 to 1.0).
  /// Throws if download fails.
  Stream<double> downloadTrack(Track track) async* {
    if (_downloadDir == null) await initialize();
    if (_completedDownloads.contains(track.videoId)) {
      yield 1.0; // Already downloaded
      return;
    }

    // 1. Get the stream URL via yt-dlp
    final streamUrl = await _ytdlp.getAudioStreamUrl(track.videoId);
    if (streamUrl == null) {
      throw Exception('Could not extract stream URL for ${track.videoId}');
    }

    // 2. Download with progress
    final outputPath = '$_downloadDir/${track.videoId}.m4a';
    _activeDownloads[track.videoId] = 0.0;

    try {
      await _dio.download(
        streamUrl,
        outputPath,
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'User-Agent': 'Mozilla/5.0',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            _activeDownloads[track.videoId] = progress;
          }
        },
      );

      _completedDownloads.add(track.videoId);
      _activeDownloads.remove(track.videoId);
      yield 1.0;
    } catch (e) {
      _activeDownloads.remove(track.videoId);
      // Clean up partial download
      final partialFile = File(outputPath);
      if (await partialFile.exists()) {
        await partialFile.delete();
      }
      rethrow;
    }
  }

  /// Delete a downloaded track.
  Future<bool> deleteDownload(Track track) async {
    for (final ext in ['m4a', 'mp3', 'opus']) {
      final file = File('$_downloadDir/${track.videoId}.$ext');
      if (await file.exists()) {
        await file.delete();
        _completedDownloads.remove(track.videoId);
        return true;
      }
    }
    return false;
  }

  /// Get all downloaded tracks as a list of file paths.
  Future<List<String>> getAllDownloadedFiles() async {
    if (_downloadDir == null) return [];
    final dir = Directory(_downloadDir!);
    if (!await dir.exists()) return [];

    final files = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        final path = entity.path;
        if (path.endsWith('.m4a') || path.endsWith('.mp3') || path.endsWith('.opus')) {
          files.add(path);
        }
      }
    }
    return files;
  }

  /// Get download progress for a specific track (0.0-1.0).
  double getProgress(Track track) =>
      _activeDownloads[track.videoId] ?? (_completedDownloads.contains(track.videoId) ? 1.0 : 0.0);

  /// Total download space used in bytes.
  Future<int> getTotalDownloadSize() async {
    final files = await getAllDownloadedFiles();
    int total = 0;
    for (final path in files) {
      final file = File(path);
      if (await file.exists()) {
        total += await file.length();
      }
    }
    return total;
  }

  /// Dispose.
  void dispose() {
    _activeDownloads.clear();
  }
}

// =======================================================================
//  Riverpod provider
// =======================================================================

final downloadServiceProvider = Provider<DownloadService>((ref) {
  final service = DownloadService();
  ref.onDispose(() => service.dispose());
  return service;
});
