import 'dart:async';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/audio_handler.dart';
import '../core/ytdlp_service.dart';
import '../models/track.dart';

// =======================================================================
//  Player State
// =======================================================================

/// Current state of the music player UI.
class PlayerState {
  final Track? currentTrack;
  final List<Track> queue;
  final int currentIndex;
  final bool isPlaying;
  final bool isLoading;
  final bool isQueueExpanded;
  final Duration position;
  final Duration duration;

  /// Color extracted from current album art (for dynamic theming).
  /// Null until album art has been processed.
  final Color? dominantColor;
  final Color? vibrantColor;

  const PlayerState({
    this.currentTrack,
    this.queue = const [],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.isLoading = false,
    this.isQueueExpanded = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.dominantColor,
    this.vibrantColor,
  });

  PlayerState copyWith({
    Track? currentTrack,
    List<Track>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? isLoading,
    bool? isQueueExpanded,
    Duration? position,
    Duration? duration,
    Color? dominantColor,
    Color? vibrantColor,
    bool clearColors = false,
  }) {
    return PlayerState(
      currentTrack: currentTrack ?? this.currentTrack,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      isQueueExpanded: isQueueExpanded ?? this.isQueueExpanded,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      dominantColor: clearColors ? null : (dominantColor ?? this.dominantColor),
      vibrantColor: clearColors ? null : (vibrantColor ?? this.vibrantColor),
    );
  }
}

// =======================================================================
//  Player Notifier
// =======================================================================

class PlayerNotifier extends StateNotifier<PlayerState> {
  final MusicAudioHandler _audioHandler;
  final YtdlpService _ytdlp;

  StreamSubscription<Track?>? _trackSub;
  StreamSubscription<List<Track>>? _queueSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;

  PlayerNotifier({
    required MusicAudioHandler audioHandler,
    required YtdlpService ytdlp,
  })  : _audioHandler = audioHandler,
        _ytdlp = ytdlp,
        super(const PlayerState()) {
    _listenToAudioHandler();
  }

  void _listenToAudioHandler() {
    _trackSub = _audioHandler.currentTrackStream.listen((track) {
      state = state.copyWith(currentTrack: track);
    });

    _queueSub = _audioHandler.queueStream.listen((queue) {
      state = state.copyWith(queue: queue);
    });

    _positionSub = _audioHandler.positionStream.listen((position) {
      state = state.copyWith(position: position);
    });

    _playingSub = _audioHandler.playingStream.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    });
  }

  // =======================================================================
  //  Transport Controls
  // =======================================================================

  Future<void> play() async {
    await _audioHandler.play();
    state = state.copyWith(isPlaying: true);
  }

  Future<void> pause() async {
    await _audioHandler.pause();
    state = state.copyWith(isPlaying: false);
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> skipToNext() async {
    await _audioHandler.skipToNext();
  }

  Future<void> skipToPrevious() async {
    await _audioHandler.skipToPrevious();
  }

  Future<void> seek(Duration position) async {
    await _audioHandler.seek(position);
  }

  // =======================================================================
  //  Track Management
  // =======================================================================

  /// Play a single track. Extracts the stream URL first if needed.
  Future<void> playTrack(Track track) async {
    state = state.copyWith(isLoading: true);

    try {
      Track resolvedTrack = track;

      // If no stream URL, extract it via yt-dlp
      if (track.streamUrl == null && track.videoId.isNotEmpty) {
        final streamUrl = await _ytdlp.getAudioStreamUrl(track.videoId);
        if (streamUrl != null) {
          resolvedTrack = track.copyWith(streamUrl: streamUrl);
        }
      }

      // If YT Music has library data, use it for radio/up-next
      await _audioHandler.playTrack(resolvedTrack);
      state = state.copyWith(
        currentTrack: resolvedTrack,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('PlayerNotifier: error playing track: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Set the full queue and start playing at [startIndex].
  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    state = state.copyWith(isLoading: true);

    // Resolve stream URLs for queued tracks (batch)
    final resolvedTracks = <Track>[];
    for (final track in tracks) {
      if (track.streamUrl != null || track.isDownloaded) {
        resolvedTracks.add(track);
      } else if (track.videoId.isNotEmpty) {
        try {
          final streamUrl = await _ytdlp.getAudioStreamUrl(track.videoId);
          resolvedTracks.add(track.copyWith(streamUrl: streamUrl));
        } catch (e) {
          resolvedTracks.add(track); // Add anyway, will skip on playback
        }
      } else {
        resolvedTracks.add(track);
      }
    }

    await _audioHandler.setQueue(resolvedTracks, startIndex: startIndex);
    state = state.copyWith(
      queue: resolvedTracks,
      currentIndex: startIndex,
      isLoading: false,
    );
  }

  /// Add tracks to the end of the queue.
  Future<void> addToQueue(List<Track> tracks) async {
    await _audioHandler.addTracks(tracks);
  }

  /// Play a track at a specific index in the queue.
  Future<void> playAtIndex(int index) async {
    state = state.copyWith(isLoading: true);
    await _audioHandler.playAtIndex(index);
    state = state.copyWith(currentIndex: index, isLoading: false);
  }

  // =======================================================================
  //  Queue UI
  // =======================================================================

  void toggleQueueExpanded() {
    state = state.copyWith(isQueueExpanded: !state.isQueueExpanded);
  }

  void setQueueExpanded(bool expanded) {
    state = state.copyWith(isQueueExpanded: expanded);
  }

  // =======================================================================
  //  Dynamic Colors
  // =======================================================================

  void setAlbumColors({Color? dominant, Color? vibrant}) {
    state = state.copyWith(
      dominantColor: dominant,
      vibrantColor: vibrant,
    );
  }

  // =======================================================================
  //  Cleanup
  // =======================================================================

  @override
  void dispose() {
    _trackSub?.cancel();
    _queueSub?.cancel();
    _positionSub?.cancel();
    _playingSub?.cancel();
    super.dispose();
  }
}

// =======================================================================
//  Providers
// =======================================================================

final playerStateProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  final ytdlp = ref.watch(ytdlpServiceProvider);

  final notifier = PlayerNotifier(
    audioHandler: audioHandler,
    ytdlp: ytdlp,
  );
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

/// Convenience provider for just the current track.
final currentTrackProvider = Provider<Track?>((ref) {
  return ref.watch(playerStateProvider.select((s) => s.currentTrack));
});

/// Convenience provider for playback state (playing/paused).
final isPlayingProvider = Provider<bool>((ref) {
  return ref.watch(playerStateProvider.select((s) => s.isPlaying));
});

/// Convenience provider for queue.
final queueProvider = Provider<List<Track>>((ref) {
  return ref.watch(playerStateProvider.select((s) => s.queue));
});

/// Convenience provider for loading state.
final isLoadingProvider = Provider<bool>((ref) {
  return ref.watch(playerStateProvider.select((s) => s.isLoading));
});
