import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/track.dart';

class LocalMediaService {
  final List<Track> _localTracks = [];
  bool _scanned = false;
  bool get scanned => _scanned;

  static const Set<String> supportedExtensions = {
    '.mp3', '.m4a', '.aac', '.flac', '.wav',
    '.ogg', '.opus', '.wma', '.webm',
  };

  List<Track> get localTracks => List.unmodifiable(_localTracks);

  Future<List<Track>> scanLocalFiles({bool includeExternal = false}) async {
    if (_scanned && _localTracks.isNotEmpty) return List.from(_localTracks);

    _localTracks.clear();

    final appDir = await getApplicationDocumentsDirectory();
    await _scanDirectory('${appDir.path}/downloads');

    try {
      final externalDirs = await getExternalStorageDirectories() ?? [];
      for (final dir in externalDirs) {
        await _scanDirectory(dir.path);
      }
    } catch (e) {
      debugPrint('LocalMediaService: path_provider dirs error: $e');
    }

    if (includeExternal) {
      await _requestStoragePermission();
      await _scanCommonAndroidDirs();
    }

    _scanned = true;
    _persistTracks();
    return List.from(_localTracks);
  }

  Future<void> _scanCommonAndroidDirs() async {
    const commonDirs = [
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Audio',
      '/sdcard/Music',
      '/sdcard/Download',
      '/storage/emulated/0/',
    ];
    for (final dir in commonDirs) {
      await _scanDirectory(dir);
    }
  }

  Future<void> _requestStoragePermission() async {
    if (await Permission.storage.isGranted) return;
    if (await Permission.manageExternalStorage.isGranted) return;
    if (await Permission.manageExternalStorage.request().isGranted) return;
    await Permission.storage.request();
  }

  Future<void> _scanDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return;

    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && _isAudioFile(entity.path)) {
          if (_localTracks.any((t) => t.localPath == entity.path)) continue;
          final track = _fileToTrack(entity);
          if (track != null) _localTracks.add(track);
        }
      }
    } catch (e) {
      debugPrint('LocalMediaService: error scanning $path: $e');
    }
  }

  bool _isAudioFile(String path) {
    final ext = path.toLowerCase();
    return supportedExtensions.any((e) => ext.endsWith(e));
  }

  Track? _fileToTrack(File file) {
    try {
      final filename = file.uri.pathSegments.last;
      final nameWithoutExt = filename.split('.').first;

      String artist = 'Unknown Artist';
      String title = nameWithoutExt;

      if (nameWithoutExt.contains(' - ')) {
        final parts = nameWithoutExt.split(' - ');
        if (parts.length >= 2) {
          artist = parts[0].trim();
          title = parts.sublist(1).join(' - ').trim();
        }
      }

      return Track(
        id: file.path.hashCode.toString(),
        videoId: '',
        title: title,
        artist: artist,
        localPath: file.path,
        isDownloaded: true,
        duration: Duration.zero,
      );
    } catch (e) {
      debugPrint('LocalMediaService: error processing ${file.path}: $e');
      return null;
    }
  }

  void _persistTracks() {
    try {
      final box = Hive.box('local_tracks');
      box.put('tracks', _localTracks.map((t) => t.toJson()).toList());
      box.put('count', _localTracks.length);
    } catch (e) {
      debugPrint('LocalMediaService: persist error: $e');
    }
  }

  void loadPersistedTracks() {
    try {
      final box = Hive.box('local_tracks');
      final data = box.get('tracks') as List<dynamic>?;
      if (data == null) return;
      _localTracks.clear();
      for (final item in data) {
        _localTracks.add(Track.fromJson(item as Map<String, dynamic>));
      }
      _scanned = _localTracks.isNotEmpty;
    } catch (e) {
      debugPrint('LocalMediaService: load persisted error: $e');
    }
  }

  Track? getTrackByPath(String path) {
    try {
      return _localTracks.firstWhere((t) => t.localPath == path);
    } catch (e) {
      return null;
    }
  }

  Future<Track?> addFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    if (!_isAudioFile(path)) return null;

    if (_localTracks.any((t) => t.localPath == path)) {
      return _localTracks.firstWhere((t) => t.localPath == path);
    }

    final track = _fileToTrack(file);
    if (track != null) {
      _localTracks.add(track);
      _persistTracks();
    }
    return track;
  }

  void removeTrack(Track track) {
    _localTracks.removeWhere((t) => t.id == track.id);
    _persistTracks();
  }

  void clear() {
    _localTracks.clear();
    _scanned = false;
  }

  void dispose() {
    _localTracks.clear();
  }
}

final localMediaServiceProvider = Provider<LocalMediaService>((ref) {
  final service = LocalMediaService();
  service.loadPersistedTracks();
  ref.onDispose(() => service.dispose());
  return service;
});
