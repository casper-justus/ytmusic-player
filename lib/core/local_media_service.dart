import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';

/// Scans and manages local/external audio files on the device.
///
/// Supports MP3, M4A/AAC, FLAC, WAV, OGG, OPUS, WMA formats.
/// Provides playback-ready Track models for each discovered file.
class LocalMediaService {
  /// List of discovered local tracks.
  final List<Track> _localTracks = [];

  /// Whether we've completed scanning.
  bool _scanned = false;
  bool get scanned => _scanned;

  /// Supported audio file extensions.
  static const Set<String> supportedExtensions = {
    '.mp3', '.m4a', '.aac', '.flac', '.wav',
    '.ogg', '.opus', '.wma', '.webm',
  };

  /// Get the list of discovered local tracks.
  List<Track> get localTracks => List.unmodifiable(_localTracks);

  /// Scan the app's download directory and optionally external storage.
  ///
  /// [includeExternal] — whether to scan external storage (SD card, etc.)
  Future<List<Track>> scanLocalFiles({bool includeExternal = false}) async {
    _localTracks.clear();

    // 1. Scan app's download directory
    final appDir = await getApplicationDocumentsDirectory();
    await _scanDirectory('${appDir.path}/downloads');

    // 2. Optionally scan external music directories
    if (includeExternal) {
      // Android common music directories
      final externalDirs = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/sdcard/Music',
        '/sdcard/Download',
      ];

      for (final dir in externalDirs) {
        await _scanDirectory(dir);
      }
    }

    _scanned = true;
    return List.from(_localTracks);
  }

  /// Scan a single directory for audio files.
  Future<void> _scanDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return;

    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && _isAudioFile(entity.path)) {
          final track = _fileToTrack(entity);
          if (track != null) {
            _localTracks.add(track);
          }
        }
      }
    } catch (e) {
      debugPrint('LocalMediaService: error scanning $path: $e');
    }
  }

  /// Check if a file path has a supported audio extension.
  bool _isAudioFile(String path) {
    final ext = path.toLowerCase();
    return supportedExtensions.any((e) => ext.endsWith(e));
  }

  /// Convert a File to a Track model with metadata.
  Track? _fileToTrack(File file) {
    try {
      final filename = file.uri.pathSegments.last;
      final nameWithoutExt = filename.split('.').first;

      // Try to parse "Artist - Title.mp3" convention
      String artist = 'Unknown Artist';
      String title = nameWithoutExt;

      if (nameWithoutExt.contains(' - ')) {
        final parts = nameWithoutExt.split(' - ');
        if (parts.length >= 2) {
          artist = parts[0].trim();
          title = parts.sublist(1).join(' - ').trim();
        }
      }

      final stat = file.statSync();

      return Track(
        id: file.path.hashCode.toString(),
        videoId: '', // Local files don't have a videoId
        title: title,
        artist: artist,
        localPath: file.path,
        isDownloaded: true,
        duration: Duration.zero, // Would need a media info reader for real duration
      );
    } catch (e) {
      debugPrint('LocalMediaService: error processing ${file.path}: $e');
      return null;
    }
  }

  /// Get a specific local track by file path.
  Track? getTrackByPath(String path) {
    try {
      return _localTracks.firstWhere((t) => t.localPath == path);
    } catch (e) {
      return null;
    }
  }

  /// Add a manually selected file (e.g., from file_picker).
  Future<Track?> addFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    if (!_isAudioFile(path)) return null;

    // Check if already added
    if (_localTracks.any((t) => t.localPath == path)) {
      return _localTracks.firstWhere((t) => t.localPath == path);
    }

    final track = _fileToTrack(file);
    if (track != null) {
      _localTracks.add(track);
    }
    return track;
  }

  /// Remove a local track.
  void removeTrack(Track track) {
    _localTracks.removeWhere((t) => t.id == track.id);
  }

  /// Clear all local tracks from the list (doesn't delete files).
  void clear() {
    _localTracks.clear();
    _scanned = false;
  }

  /// Dispose.
  void dispose() {
    _localTracks.clear();
  }
}

// =======================================================================
//  Riverpod provider
// =======================================================================

final localMediaServiceProvider = Provider<LocalMediaService>((ref) {
  final service = LocalMediaService();
  ref.onDispose(() => service.dispose());
  return service;
});
