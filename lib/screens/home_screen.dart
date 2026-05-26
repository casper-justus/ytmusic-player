import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../models/track.dart';
import '../widgets/now_playing_bar.dart';

/// YouTube Music home feed — recommendations, quick picks, mixes.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load home sections on first build
    Future.microtask(() {
      ref.read(libraryProvider.notifier).loadHomeSections();
    });
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: _buildBody(library, isDark),
      bottomNavigationBar: const NowPlayingBar(),
      bottomSheet: library.isLoggedIn
          ? null
          : _buildLoginPrompt(context),
    );
  }

  Widget _buildBody(LibraryState library, bool isDark) {
    if (library.isLoading && library.homeSections.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (library.homeSections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Sign in to get recommendations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Or search for music to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(libraryProvider.notifier).loadHomeSections(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: library.homeSections.length,
        itemBuilder: (context, index) {
          final section = library.homeSections[index];
          return _HomeSectionCard(
            section: section,
            onTrackTap: (track) {
              ref.read(playerStateProvider.notifier).playTrack(track);
            },
          );
        },
      ),
    );
  }

  Widget? _buildLoginPrompt(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sign in to YouTube Music',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  'Get playlists, recommendations, and your library',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}

/// A horizontal scrolling row of items from a home section.
class _HomeSectionCard extends StatelessWidget {
  final Map<String, dynamic> section;
  final ValueChanged<Track> onTrackTap;

  const _HomeSectionCard({
    required this.section,
    required this.onTrackTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = section['title'] as String? ?? 'Browse';
    final contents = section['contents'] as List<dynamic>? ?? [];

    if (contents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: contents.length,
            itemBuilder: (context, index) {
              final item = contents[index] as Map<String, dynamic>;
              return _HomeItem(
                item: item,
                onTap: () {
                  final videoId = item['videoId'] as String?;
                  if (videoId != null && videoId.isNotEmpty) {
                    onTrackTap(Track(
                      id: videoId,
                      videoId: videoId,
                      title: item['title'] as String? ?? '',
                      artist: '',
                      albumArtUrl: _bestThumbnail(item['thumbnails']),
                    ));
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String? _bestThumbnail(dynamic thumbnails) {
    if (thumbnails == null) return null;
    if (thumbnails is List && thumbnails.isNotEmpty) {
      // Return the second-to-last (typically best quality)
      final last = thumbnails.last as Map;
      return last['url'] as String?;
    }
    return null;
  }
}

class _HomeItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _HomeItem({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = item['title'] as String? ?? '';
    final artists = item['artists'] as List<dynamic>?;
    final subtitle = artists != null && artists.isNotEmpty
        ? (artists.first is Map ? (artists.first as Map)['name'] as String? : artists.first as String?)
        : (item['artist'] as String?);

    final thumbnailUrl = _thumbnail();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: thumbnailUrl != null
                  ? CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      height: 150,
                      width: 150,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.music_note, size: 40),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.music_note, size: 40),
                      ),
                    )
                  : Container(
                      height: 150,
                      color: Colors.grey[800],
                      child: const Icon(Icons.music_note, size: 40),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  String? _thumbnail() {
    final thumbnails = item['thumbnails'];
    if (thumbnails is List && thumbnails.isNotEmpty) {
      return (thumbnails.last as Map)['url'] as String?;
    }
    return null;
  }
}
