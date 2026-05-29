import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';

class MusicAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  List<Track> _queue = [];
  int _currentIndex = 0;
  bool _initialized = false;

  final _currentTrackController = StreamController<Track?>.broadcast();
  Stream<Track?> get currentTrackStream => _currentTrackController.stream;

  final _queueController = StreamController<List<Track>>.broadcast();
  Stream<List<Track>> get queueStream => _queueController.stream;

  MusicAudioHandler() {
    _setupPlayerListeners();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    await _player.setVolume(1.0);
    _initialized = true;
  }

  void _setupPlayerListeners() {
    _player.playbackEventStream.listen(_onPlaybackEvent);
    _player.processingStateStream.listen(_onProcessingState);
    _player.positionStream.listen((position) {
      final current = playbackState.valueOrNull;
      if (current != null) {
        playbackState.add(current.copyWith(updatePosition: position));
      }
    });
  }

  void _onPlaybackEvent(PlaybackEvent event) {
    playbackState.add(_transformEvent(event));
  }

  void _onProcessingState(ProcessingState state) {
    if (state == ProcessingState.completed) {
      _advanceToNext();
    }
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapProcessingState(_player.processingState),
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentIndex,
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    _queue = List.from(tracks);
    _currentIndex = startIndex.clamp(0, _queue.length - 1);
    _queueController.add(_queue);
    queue.add(_queue.map(_trackToMediaItem).toList());

    if (_queue.isNotEmpty) {
      await _playCurrent();
    }
  }

  Future<void> addTracks(List<Track> tracks) async {
    _queue.addAll(tracks);
    _queueController.add(_queue);
    queue.add(_queue.map(_trackToMediaItem).toList());

    if (!_player.playing && _player.processingState == ProcessingState.idle) {
      _currentIndex = _queue.length - tracks.length;
      await _playCurrent();
    }
  }

  Future<void> playAtIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await _playCurrent();
  }

  Future<void> playTrack(Track track) async {
    final existingIndex = _queue.indexWhere((t) => t.id == track.id);
    if (existingIndex >= 0) {
      _currentIndex = existingIndex;
    } else {
      _queue.add(track);
      _currentIndex = _queue.length - 1;
      _queueController.add(_queue);
      queue.add(_queue.map(_trackToMediaItem).toList());
    }
    await _playCurrent();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _advanceToNext();

  @override
  Future<void> skipToPrevious() async {
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
    } else {
      _currentIndex = (_currentIndex - 1).clamp(0, _queue.length - 1);
      await _playCurrent();
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    super.setRepeatMode(repeatMode);
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        _player.setLoopMode(LoopMode.off);
      case AudioServiceRepeatMode.one:
        _player.setLoopMode(LoopMode.one);
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        _player.setLoopMode(LoopMode.all);
    }
  }

  Future<void> _playCurrent() async {
    if (_queue.isEmpty) return;

    final track = _queue[_currentIndex];
    _currentTrackController.add(track);
    mediaItem.add(_trackToMediaItem(track));

    AudioSource? source;
    if (track.contentUri != null) {
      source = AudioSource.uri(Uri.parse(track.contentUri!));
    } else if (track.isDownloaded && track.localPath != null) {
      source = AudioSource.file(track.localPath!);
    } else if (track.streamUrl != null) {
      source = AudioSource.uri(Uri.parse(track.streamUrl!));
    }

    if (source == null) {
      debugPrint('AudioHandler: no audio source for track  () — skipping');
      await _advanceToNext();
      return;
    }

    try {
      await _player.setAudioSource(source);
      await _player.play();
    } catch (e) {
      debugPrint('AudioHandler: playback failed for track  ()');
      debugPrint('');
      await _advanceToNext();
    }
  }

  Future<void> _advanceToNext() async {
    if (_queue.isEmpty) return;

    final currentRepeatMode = playbackState.valueOrNull?.repeatMode ?? AudioServiceRepeatMode.none;

    if (currentRepeatMode == AudioServiceRepeatMode.one) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }

    if (_currentIndex + 1 < _queue.length) {
      _currentIndex++;
    } else if (currentRepeatMode == AudioServiceRepeatMode.all ||
        currentRepeatMode == AudioServiceRepeatMode.group) {
      _currentIndex = 0;
    } else {
      await _player.pause();
      _currentTrackController.add(null);
      return;
    }

    await _playCurrent();
  }

  MediaItem _trackToMediaItem(Track track) {
    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album ?? '',
      artUri: track.albumArtUrl != null ? Uri.tryParse(track.albumArtUrl!) : null,
      duration: track.duration,
    );
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _currentTrackController.close();
    await _queueController.close();
  }

  Track? get currentTrack =>
      _queue.isNotEmpty && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;

  int get currentIndex => _currentIndex;
  bool get isPlaying => _player.playing;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
  String? get currentStreamUrl => currentTrack?.streamUrl;

  Future<void> setVolume(double volume) => _player.setVolume(volume);
}

final audioHandlerProvider = Provider<MusicAudioHandler>((ref) {
  final handler = MusicAudioHandler();
  ref.onDispose(() => handler.dispose());
  return handler;
});
