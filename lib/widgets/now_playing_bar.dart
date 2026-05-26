import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/player_provider.dart';

/// A mini player bar shown at the bottom of all screens when a track
/// is actively playing or paused.
///
/// Shows album art, track title, artist, play/pause, and tap to open
/// the full player screen.
class NowPlayingBar extends ConsumerWidget {
  const NowPlayingBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);
    final track = state.currentTrack;

    // Don't show the bar if nothing is loaded or playing
    if (track == null && !state.isLoading) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/player'),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border(
            top: BorderSide(
              color: Colors.grey[800]!,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Album art
            if (track?.albumArtUrl != null)
              ClipRRect(
                child: CachedNetworkImage(
                  imageUrl: track!.albumArtUrl!,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _placeholderBox(),
                  errorWidget: (_, __, ___) => _placeholderBox(),
                ),
              )
            else
              _placeholderBox(),

            // Track info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track?.title ?? 'Loading...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track?.artist ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            // Play/Pause
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: Icon(
                  state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 28,
                ),
                onPressed: () {
                  ref.read(playerStateProvider.notifier).togglePlayPause();
                },
              ),

            // Skip next
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, size: 28),
              onPressed: () {
                ref.read(playerStateProvider.notifier).skipToNext();
              },
            ),

            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _placeholderBox() => Container(
        width: 64,
        height: 64,
        color: Colors.grey[800],
        child: Icon(Icons.music_note, color: Colors.grey[600]),
      );
}
