import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/album.dart';
import '../models/track.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/track_list_tile.dart';

/// Full-screen album detail view.
///
/// Shows album art, artist info, year, track list with number indices,
/// and a play-all button.
class AlbumDetailScreen extends ConsumerStatefulWidget {
  final Album album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  ConsumerState<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<AlbumDetailScreen> {
  late Future<List<Track>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    if (widget.album.tracks.isNotEmpty) {
      _tracksFuture = Future.value(widget.album.tracks);
    } else {
      _tracksFuture = ref.read(libraryProvider.notifier).getAlbumTracks(widget.album.id);
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
          final tracks = snapshot.data ?? widget.album.tracks;

          return CustomScrollView(
            slivers: [
              // -- Album Header --
              SliverAppBar(
                expandedHeight: 320,
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
                              tracks[0],
                            )
                        : null,
                  ),
                ],
              ),

              // -- Play All --
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

              // -- Track list with index numbers --
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
            leading: SizedBox(
              width: 24,
              child: Text(
                '${index + 1}',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
onTap: () {
                        ref.read(playerStateProvider.notifier).playTrack(track);
                        if (index + 1 < tracks.length) {
                          ref.read(playerStateProvider.notifier).addToQueue(
                              tracks.sublist(index + 1));
                        }
                      },
                      );
                    },
                    childCount: tracks.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool hasTracks) {
    final a = widget.album;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background art
        if (a.imageUrl != null)
          CachedNetworkImage(
            imageUrl: a.imageUrl!,
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
                a.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                a.artist,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[300],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (a.year != null)
                    Text(
                      '${a.year}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  if (a.year != null) const SizedBox(width: 8),
                  Text(
                    '${a.trackCount} tracks${hasTracks ? '' : ' — loading...'}',
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
        child: Icon(Icons.album, size: 80, color: Colors.grey[600]),
      ),
    );
  }
}
