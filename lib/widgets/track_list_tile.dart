import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/track.dart';
import '../providers/player_provider.dart';
import 'download_button.dart';

/// A reusable track list tile used in playlist/album detail screens,
/// search results, and the library view.
///
/// [track] — the track to display
/// [onTap] — called when the tile is tapped (defaults to playing the track)
/// [leading] — optional widget before the album art (e.g., track number)
/// [trailing] — optional widget after the duration (overrides default DownloadButton)
/// [showArt] — whether to show the album art thumbnail (default true)
/// [showDownload] — whether to show the download button (default true)
class TrackListTile extends ConsumerWidget {
  final Track track;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final bool showArt;
  final bool showDownload;

  const TrackListTile({
    super.key,
    required this.track,
    this.onTap,
    this.leading,
    this.trailing,
    this.showArt = true,
    this.showDownload = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final isCurrentTrack = playerState.currentTrack?.id == track.id;

    return ListTile(
      leading: _buildLeading(context),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.normal,
          color: isCurrentTrack ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      subtitle: Row(
        children: [
          Flexible(
            child: Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          if (track.album != null) ...[
            const Text(' • ', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Flexible(
              child: Text(
                track.album!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
          ],
        ],
      ),
      trailing: trailing ??
          (showDownload
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DurationLabel(duration: track.duration),
                    const SizedBox(width: 4),
                    DownloadButton(track: track, iconSize: 20),
                  ],
                )
              : _DurationLabel(duration: track.duration)),
      onTap: onTap ?? () => ref.read(playerStateProvider.notifier).playTrack(track),
    );
  }

  Widget? _buildLeading(BuildContext context) {
    if (leading != null) return leading;

    if (!showArt) return null;

    final hasArt = track.albumArtUrl != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 48,
        height: 48,
        child: hasArt
            ? CachedNetworkImage(
                imageUrl: track.albumArtUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(Icons.music_note, size: 24),
    );
  }
}

class _DurationLabel extends StatelessWidget {
  final Duration duration;
  const _DurationLabel({required this.duration});

  @override
  Widget build(BuildContext context) {
    if (duration == Duration.zero) return const SizedBox.shrink();

    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final text = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Text(
      text,
      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
    );
  }
}
