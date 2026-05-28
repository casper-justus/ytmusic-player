import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import '../providers/player_provider.dart';
import '../models/track.dart';
import '../core/cast_service.dart';
import '../widgets/cast_dialog.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerStateProvider);
    final track = state.currentTrack;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (track == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_note, size: 100, color: Colors.grey[400]),
              const SizedBox(height: 24),
              Text(
                'No track playing',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    final bgColor = state.dominantColor ?? (isDark ? Colors.black : const Color(0xFF1A1A2E));
    final accentColor = state.vibrantColor ?? Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accentColor.withValues(alpha: 0.25),
              bgColor,
              bgColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _AppBar(accentColor: accentColor),
              Expanded(child: _AlbumArt(track: track)),
              _TrackInfo(track: track),
              _ProgressBar(),
              _Controls(state: state, accentColor: accentColor),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBar extends ConsumerWidget {
  final Color accentColor;
  const _AppBar({required this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final castService = ref.watch(castServiceProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          SizedBox(
            height: 36,
            width: 36,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                castService.connected ? Icons.cast_connected : Icons.cast_outlined,
                size: 20,
                color: castService.connected ? Colors.blue : null,
              ),
              onPressed: () => showCastDialog(context),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 36,
            width: 36,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.queue_music_outlined, size: 20),
              onPressed: () => ref.read(playerStateProvider.notifier).toggleQueueExpanded(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumArt extends ConsumerStatefulWidget {
  final Track track;
  const _AlbumArt({required this.track});

  @override
  ConsumerState<_AlbumArt> createState() => _AlbumArtState();
}

class _AlbumArtState extends ConsumerState<_AlbumArt> {
  @override
  void initState() {
    super.initState();
    _extractColors();
  }

  @override
  void didUpdateWidget(covariant _AlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id) _extractColors();
  }

  Future<void> _extractColors() async {
    if (widget.track.albumArtUrl == null) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(widget.track.albumArtUrl!),
        maximumColorCount: 16,
      );
      if (mounted) {
        ref.read(playerStateProvider.notifier).setAlbumColors(
              dominant: palette.dominantColor?.color,
              vibrant: palette.vibrantColor?.color,
            );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Hero(
          tag: 'album-art-${widget.track.id}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: widget.track.albumArtUrl != null
                    ? CachedNetworkImage(
                        imageUrl: widget.track.albumArtUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _placeholder(),
                        errorWidget: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: Colors.grey[850],
        child: const Icon(Icons.music_note, size: 80, color: Colors.grey),
      );
}

class _TrackInfo extends StatelessWidget {
  final Track track;
  const _TrackInfo({required this.track});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  track.artist,
                  style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.favorite_outline, size: 22),
            onPressed: () {},
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);
    final duration = state.duration;
    final position = state.position;
    final remaining = duration - position;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white10,
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (value) {
                final newPosition = Duration(
                  milliseconds: (duration.inMilliseconds * value).round(),
                );
                ref.read(playerStateProvider.notifier).seek(newPosition);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(position),
                    style: const TextStyle(fontSize: 11, color: Colors.white54)),
                Text('-${_formatDuration(remaining)}',
                    style: const TextStyle(fontSize: 11, color: Colors.white54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}${m.toString().padLeft(d.inHours > 0 ? 2 : 1, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _Controls extends ConsumerWidget {
  final PlayerState state;
  final Color accentColor;
  const _Controls({required this.state, required this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(playerStateProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(Icons.shuffle, size: 22, color: Colors.grey[400]),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, size: 30),
            onPressed: () => notifier.skipToPrevious(),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 36,
              ),
              color: Colors.black87,
              onPressed: () => notifier.togglePlayPause(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next_rounded, size: 30),
            onPressed: () => notifier.skipToNext(),
          ),
          IconButton(
            icon: Icon(Icons.repeat, size: 22, color: Colors.grey[400]),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
