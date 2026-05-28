import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/track.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/now_playing_bar.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  List<Track> _results = [];
  bool _isSearching = false;
  List<String> _history = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (value.length > 2) {
        _performSearch(value);
      } else if (value.isEmpty) {
        setState(() => _results = []);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final results = await ref.read(libraryProvider.notifier).searchSongs(query.trim());
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
      _saveToHistory(query.trim());
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _saveToHistory(String query) async {
    final box = Hive.box<String>('search_history');
    final keys = box.keys.toList();
    for (final key in keys) {
      if (box.get(key) == query) {
        await box.delete(key);
        break;
      }
    }
    await box.add(query);
    if (box.length > 20) {
      await box.deleteAt(0);
    }
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final box = Hive.box<String>('search_history');
    setState(() => _history = box.values.toList().reversed.toList());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(28),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Search songs, albums, artists...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  prefixIcon: const Icon(Icons.search, size: 22),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _results = []);
                          },
                        )
                      : null,
                ),
                onSubmitted: _performSearch,
                onChanged: (value) {
                  setState(() {});
                  _onSearchChanged(value);
                },
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: const NowPlayingBar(),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchController.text.isEmpty) {
      if (_history.isNotEmpty) return _buildHistory();
      return _buildEmptyState();
    }
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No results found for "${_searchController.text}"',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final track = _results[index];
        return _SearchResultTile(
          track: track,
          onTap: () => ref.read(playerStateProvider.notifier).playTrack(track),
          onAddToQueue: () {
            ref.read(playerStateProvider.notifier).addToQueue([track]);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${track.title} added to queue')),
            );
          },
        );
      },
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              TextButton(
                onPressed: () async {
                  await Hive.box<String>('search_history').clear();
                  _loadHistory();
                },
                child: const Text('Clear All', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final query = _history[index];
              return ListTile(
                leading: const Icon(Icons.history, size: 20),
                title: Text(query),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () async {
                    final box = Hive.box<String>('search_history');
                    final key = box.keys.firstWhere((k) => box.get(k) == query);
                    await box.delete(key);
                    _loadHistory();
                  },
                ),
                onTap: () {
                  _searchController.text = query;
                  _searchController.selection = TextSelection.fromPosition(
                    TextPosition(offset: query.length),
                  );
                  _performSearch(query);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Search for your favorite music',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching for songs, albums, or artists',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  final VoidCallback onAddToQueue;

  const _SearchResultTile({
    required this.track,
    required this.onTap,
    required this.onAddToQueue,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: track.albumArtUrl != null
            ? CachedNetworkImage(
                imageUrl: track.albumArtUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.music_note, size: 24),
                ),
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.add_circle_outline),
        onPressed: onAddToQueue,
        tooltip: 'Add to queue',
      ),
      onTap: onTap,
    );
  }
}
