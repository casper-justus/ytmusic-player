import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';

/// AudioHandler that manages background playback, queue management,
/// and native Android media notifications.
///
/// This is the central audio controller for the app. It:
/// - Manages a queue of tracks (via [addTracks], [playTrack])
/// - Streams audio via just_audio (ExoPlayer under the hood)
/// - Publishes playback state updates for the UI
/// - Handles media notifications, lock screen controls
/// - Responds to headset/media button events
class MusicAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  /// The current queue of tracks.
  List<Track> _queue = [];

  /// Index of the currently playing (or queued) track in [_queue].
  int _currentIndex = 0;

  /// Whether the handler has been initialized.
  bool _initialized = false;

  /// Stream of current track updates for Riverpod/UI.
  final _currentTrackController = StreamController<Track?>.broadcast();
  Stream<Track?> get currentTrackStream => _currentTrackController.stream;

  /// Stream of queue changes.
  final _queueController = StreamController<List<Track>>.broadcast();
  Stream<List<Track>> get queueStream => _queueController.stream;

  MusicAudioHandler() {
    _setupPlayerListeners();
  }

  /// Initialize the player and audio session.
  Future<void> initialize() async {
    if (_initialized) return;
    await _player.setVolume(1.0);
    _initialized = true;
  }

  /// Set up internal player event listeners that forward to [playbackState].
  void _setupPlayerListeners() {
    _player.playbackEventStream.listen(_onPlaybackEvent);
    _player.processingStateStream.listen(_onProcessingState);
    _player.positionStream.listen((position) {
      // Update playback state with position
      final state = playbackState.valueOrNull;
      if (state != null) {
        playbackState.add(state.copyWith(updatePosition: position));
      }
    });
  }

  void _onPlaybackEvent(PlaybackEvent event) {
    playbackState.add(_transformEvent(event));
  }

  void _onProcessingState(ProcessingState state) {
    // Auto-advance to next track when current ends
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

  // =======================================================================
  //  Public API — Queue Management
  // =======================================================================

  /// Replace the entire queue with [tracks] and start playing [startIndex].
  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    _queue = List.from(tracks);
    _currentIndex = startIndex.clamp(0, _queue.length - 1);
    _queueController.add(_queue);

    if (_queue.isNotEmpty) {
      await _playCurrent();
    }
  }

  /// Add [tracks] to the end of the queue.
  Future<void> addTracks(List<Track> tracks) async {
    _queue.addAll(tracks);
    _queueController.add(_queue);

    // If nothing is playing, start with the first new track
    if (!_player.playing && _player.processingState == ProcessingState.idle) {
      _currentIndex = _queue.length - tracks.length;
      await _playCurrent();
    }
  }

  /// Play a specific track by index in the queue.
  Future<void> playAtIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await _playCurrent();
  }

  /// Play a specific [track] immediately, optionally adding it to the queue.
  Future<void> playTrack(Track track) async {
    // Check if it's already in the queue
    final existingIndex = _queue.indexWhere((t) => t.id == track.id);
    if (existingIndex >= 0) {
      _currentIndex = existingIndex;
    } else {
      // Add to queue and start playing
      _queue.add(track);
      _currentIndex = _queue.length - 1;
      _queueController.add(_queue);
    }
    await _playCurrent();
  }

  // =======================================================================
  //  Transport Controls (overrides from BaseAudioHandler)
  // =======================================================================

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
      // Restart current track if past 3 seconds
      await _player.seek(Duration.zero);
    } else {
      // Go to previous track
      _currentIndex = (_currentIndex - 1).clamp(0, _queue.length - 1);
      await _playCurrent();
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _player.setAudioSource(null);
    _queueController.add(_queue);
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
        _player.setLoopMode(LoopMode.all);
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    super.setShuffleMode(shuffleMode);
    // Shuffle handling would randomize _queue order
  }

  @override
  Future<void> setQueue(List<MediaItem> queue, {int? index}) async {
    // audio_service may call this; we handle our own queue
  }

  overrideAudioSession(AudioSessionConfiguration config) {
    // Configure for music playback
    AudioSessionConfiguration.music().setAsActive();
  }

  // =======================================================================
  //  Internal
  // =======================================================================

  Future<void> _playCurrent() async {
    if (_queue.isEmpty) return;

    final track = _queue[_currentIndex];
    _currentTrackController.add(track);

    // Update the media item for the notification
    mediaItem.add(MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album ?? '',
      artUri: track.albumArtUrl != null ? Uri.tryParse(track.albumArtUrl!) : null,
      duration: track.duration,
    ));

    // Determine the audio source
    AudioSource source;
    if (track.isDownloaded && track.localPath != null) {
      // Play from local file
      source = AudioSource.file(track.localPath!);
    } else if (track.streamUrl != null) {
      // Play from stream URL
      source = AudioSource.uri(Uri.parse(track.streamUrl!));
    } else {
      // No source available — skip
      await _advanceToNext();
      return;
    }

    await _player.setAudioSource(source);
    await _player.play();
  }

  Future<void> _advanceToNext() async {
    if (_queue.isEmpty) return;

    final repeatMode = this.repeatMode.valueOrNull ?? AudioServiceRepeatMode.none;

    if (repeatMode == AudioServiceRepeatMode.one) {
      // Restart current track
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }

    if (_currentIndex + 1 < _queue.length) {
      _currentIndex++;
    } else if (repeatMode == AudioServiceRepeatMode.all) {
      _currentIndex = 0; // Wrap around
    } else {
      // End of queue, stop
      await _player.pause();
      _currentTrackController.add(null);
      return;
    }

    await _playCurrent();
  }

  /// Dispose all resources.
  Future<void> dispose() async {
    await _player.dispose();
    await _currentTrackController.close();
    await _queueController.close();
  }

  // =======================================================================
  //  Accessors
  // =======================================================================

  Track? get currentTrack =>
      _queue.isNotEmpty && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;

  List<Track> get queue => List.unmodifiable(_queue);

  int get currentIndex => _currentIndex;

  bool get isPlaying => _player.playing;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;

  /// The stream URL for the current track, or null if none.
  String? get currentStreamUrl => currentTrack?.streamUrl;

  Future<void> setVolume(double volume) => _player.setVolume(volume);
}

// =======================================================================
//  Riverpod provider
// =======================================================================

final audioHandlerProvider = Provider<MusicAudioHandler>((ref) {
  final handler = MusicAudioHandler();
  ref.onDispose(() => handler.dispose());
  return handler;
});
