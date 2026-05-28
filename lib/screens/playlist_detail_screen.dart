import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/playlist_item.dart';
import '../models/track.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/track_list_tile.dart';

/// Full-screen playlist detail view.
///
/// Shows the playlist header (image, title, description, stats),
/// a "Play All" button, and the full track list.
class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final PlaylistItem playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  late Future<List<Track>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    if (widget.playlist.tracks.isNotEmpty) {
      _tracksFuture = Future.value(widget.playlist.tracks);
    } else {
      _tracksFuture = ref.read(libraryProvider.notifier).getPlaylistTracks(widget.playlist.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: FutureBuilder<List<Track>>(
        future: _tracksFuture,
        builder: (context, snapshot) {
          final tracks = snapshot.data ?? widget.playlist.tracks;

          return CustomScrollView(
            slivers: [
              // -- Header --
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeader(isDark, tracks.isNotEmpty),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.shuffle),
                    tooltip: 'Shuffle Play',
                    onPressed: tracks.isNotEmpty
                        ? () => ref.read(playerStateProvider.notifier).playTrack(
                              tracks[(tracks.length * 0).round()], // will shuffle via provider
                            )
                        : null,
                  ),
                ],
              ),

              // -- Play All button --
              if (tracks.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverToBoxAdapter(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: Text('Play All (${tracks.length})'),
              onPressed: () {
                ref.read(playerStateProvider.notifier).playTrack(tracks.first);
                if (tracks.length > 1) {
                  ref.read(playerStateProvider.notifier).addToQueue(
                      tracks.sublist(1));
                }
              },
                    ),
                  ),
                ),

              // -- Track list --
              if (snapshot.hasError)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Failed to load tracks: ${snapshot.error}',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = tracks[index];
                      return TrackListTile(
                        track: track,
                        onTap: () => ref.read(playerStateProvider.notifier).playTrack(track),
                      );
                    },
                    childCount: tracks.length,
                  ),
                ),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool hasTracks) {
    final p = widget.playlist;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image
        if (p.imageUrl != null)
          CachedNetworkImage(
            imageUrl: p.imageUrl!,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _placeholderHeader(isDark),
          )
        else
          _placeholderHeader(isDark),

        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                isDark ? Colors.black.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85),
              ],
            ),
          ),
        ),

        // Info overlay
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (p.description != null && p.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  p.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[300],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  if (p.owner != null)
                    Text(
                      p.owner!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  if (p.owner != null) const SizedBox(width: 8),
                  Text(
                    '${p.trackCount} tracks${hasTracks ? '' : ' — loading...'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Back button
        const Positioned(
          top: 8,
          left: 4,
          child: BackButton(color: Colors.white),
        ),
      ],
    );
  }

  Widget _placeholderHeader(bool isDark) {
    return Container(
      color: isDark ? Colors.grey[900] : Colors.grey[300],
      child: Center(
        child: Icon(Icons.queue_music, size: 80, color: Colors.grey[600]),
      ),
    );
  }
}
