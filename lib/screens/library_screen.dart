import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../models/playlist_item.dart';
import '../models/track.dart';
import '../widgets/now_playing_bar.dart';

/// Library screen — playlists, liked songs, albums.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    Future.microtask(() {
      final library = ref.read(libraryProvider.notifier);
      library.loadPlaylists();
      library.loadLikedSongs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    ref.listen(libraryProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(next.error!),
                duration: const Duration(seconds: 6),
                action: SnackBarAction(
                  label: 'Sign In',
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                ),
              ),
            );
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Playlists'),
            Tab(text: 'Liked Songs'),
            Tab(text: 'Downloads'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PlaylistsTab(playlists: library.playlists),
          _LikedSongsTab(tracks: library.likedSongs),
          _DownloadsTab(),
        ],
      ),
      bottomNavigationBar: const NowPlayingBar(),
    );
  }
}

class _PlaylistsTab extends StatelessWidget {
  final List<PlaylistItem> playlists;
  const _PlaylistsTab({required this.playlists});

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.queue_music, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No playlists yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to see your YouTube Music playlists',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: playlist.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: playlist.imageUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _placeholderIcon(),
                  )
                : _placeholderIcon(),
          ),
          title: Text(playlist.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${playlist.trackCount} tracks',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // Navigate to playlist detail
            Navigator.pushNamed(context, '/playlist', arguments: playlist);
          },
        );
      },
    );
  }

  Widget _placeholderIcon() => Container(
        width: 56,
        height: 56,
        color: Colors.grey[800],
        child: const Icon(Icons.queue_music, size: 28),
      );
}

class _LikedSongsTab extends ConsumerWidget {
  final List<Track> tracks;
  const _LikedSongsTab({required this.tracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No liked songs yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: track.albumArtUrl != null
                ? CachedNetworkImage(
                    imageUrl: track.albumArtUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.music_note, size: 24),
                    ),
                  )
                : Container(
                    width: 48,
                    height: 48,
                    color: Colors.grey[800],
                    child: const Icon(Icons.music_note, size: 24),
                  ),
          ),
          title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            track.artist,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          onTap: () {
            ref.read(playerStateProvider.notifier).playTrack(track);
          },
        );
      },
    );
  }
}

class _DownloadsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_done, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Offline downloads',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Download tracks for offline playback',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }
}
