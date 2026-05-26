import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import '../providers/player_provider.dart';
import '../models/track.dart';

/// Full-screen now-playing view with album art, controls, queue, and
/// dynamic background coloration from the current track's album art.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final track = playerState.currentTrack;

    return Scaffold(
      body: _buildBody(playerState, track),
    );
  }

  Widget _buildBody(PlayerState state, Track? track) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (track == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 100, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'No track playing',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    // Dynamic background colors
    final bgColor = state.dominantColor ?? (isDark ? Colors.black : Colors.white);
    final accentColor = state.vibrantColor ?? Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accentColor.withValues(alpha: 0.3),
            bgColor,
            bgColor,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _AppBar(accentColor: accentColor),
            Expanded(child: _AlbumArt(track: track, accentColor: accentColor)),
            _TrackInfo(track: track, accentColor: accentColor),
            _ProgressBar(),
            _Controls(state: state, accentColor: accentColor),
            _VolumeRow(accentColor: accentColor),
            if (state.isQueueExpanded) _QueueList(),
          ],
        ),
      ),
    );
  }
}

// =======================================================================
//  App Bar (back, queue toggle, cast)
// =======================================================================

class _AppBar extends ConsumerWidget {
  final Color accentColor;
  const _AppBar({required this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Minimize',
          ),
          Text(
            'Now Playing',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: accentColor,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.queue_music_outlined),
                onPressed: () {
                  ref.read(playerStateProvider.notifier).toggleQueueExpanded();
                },
                tooltip: 'Queue',
              ),
              IconButton(
                icon: const Icon(Icons.cast_outlined),
                onPressed: () {
                  // Open Cast dialog
                },
                tooltip: 'Cast',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =======================================================================
//  Album Art
// =======================================================================

class _AlbumArt extends ConsumerStatefulWidget {
  final Track track;
  final Color accentColor;
  const _AlbumArt({required this.track, required this.accentColor});

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
    if (oldWidget.track.id != widget.track.id) {
      _extractColors();
    }
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
    } catch (e) {
      // Silently fail — colors stay as defaults
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: widget.track.albumArtUrl != null
            ? CachedNetworkImage(
                imageUrl: widget.track.albumArtUrl!,
                width: 300,
                height: 300,
                fit: BoxFit.cover,
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 300,
        height: 300,
        color: Colors.grey[800],
        child: Icon(Icons.music_note, size: 100, color: Colors.grey[600]),
      );
}

// =======================================================================
//  Track Info
// =======================================================================

class _TrackInfo extends StatelessWidget {
  final Track track;
  final Color accentColor;
  const _TrackInfo({required this.track, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  track.artist,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (track.album != null)
                  Text(
                    track.album!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              // Like/unlike track
            },
            color: accentColor,
          ),
        ],
      ),
    );
  }
}

// =======================================================================
//  Progress Bar
// =======================================================================

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
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Theme.of(context).colorScheme.primary,
              inactiveTrackColor: Colors.grey[700],
              thumbColor: Theme.of(context).colorScheme.primary,
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
                Text(_formatDuration(position), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(' -${_formatDuration(remaining)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}${minutes.toString().padLeft(d.inHours > 0 ? 2 : 1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// =======================================================================
//  Transport Controls
// =======================================================================

class _Controls extends ConsumerWidget {
  final PlayerState state;
  final Color accentColor;
  const _Controls({required this.state, required this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(playerStateProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Shuffle
          IconButton(
            icon: const Icon(Icons.shuffle),
            onPressed: () {},
            color: Colors.grey[400],
            iconSize: 24,
          ),
          // Previous
          _ControlButton(
            icon: Icons.skip_previous_rounded,
            onPressed: () => notifier.skipToPrevious(),
            size: 36,
          ),
          // Play/Pause
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor,
            ),
            child: IconButton(
              icon: Icon(
                state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 40,
              ),
              color: Colors.white,
              onPressed: () => notifier.togglePlayPause(),
            ),
          ),
          // Next
          _ControlButton(
            icon: Icons.skip_next_rounded,
            onPressed: () => notifier.skipToNext(),
            size: 36,
          ),
          // Repeat
          IconButton(
            icon: const Icon(Icons.repeat),
            onPressed: () {},
            color: Colors.grey[400],
            iconSize: 24,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  const _ControlButton({
    required this.icon,
    required this.onPressed,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: size),
      onPressed: onPressed,
    );
  }
}

// =======================================================================
//  Volume
// =======================================================================

class _VolumeRow extends StatelessWidget {
  final Color accentColor;
  const _VolumeRow({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.volume_down, size: 16, color: Colors.grey[500]),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                activeTrackColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[700],
                thumbColor: Colors.grey[400],
              ),
              child: const Slider(value: 1.0, onChanged: null),
            ),
          ),
          Icon(Icons.volume_up, size: 16, color: Colors.grey[500]),
        ],
      ),
    );
  }
}

// =======================================================================
//  Queue List (expandable)
// =======================================================================

class _QueueList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Up Next (${state.queue.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(playerStateProvider.notifier).toggleQueueExpanded();
                  },
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: state.queue.length,
              itemBuilder: (context, index) {
                final track = state.queue[index];
                final isCurrent = index == state.currentIndex;

                return ListTile(
                  dense: true,
                  leading: Icon(
                    isCurrent ? Icons.play_arrow : Icons.music_note,
                    size: 18,
                    color: isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  onTap: () {
                    ref.read(playerStateProvider.notifier).playAtIndex(index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
