import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/ytmusic_service.dart';
import '../models/playlist_item.dart';
import '../models/album.dart';
import '../models/track.dart';

class LibraryState {
  final List<PlaylistItem> playlists;
  final List<Album> albums;
  final List<Track> likedSongs;
  final List<Map<String, dynamic>> homeSections;
  final bool isLoading;
  final bool isLoggedIn;
  final String? error;

  const LibraryState({
    this.playlists = const [],
    this.albums = const [],
    this.likedSongs = const [],
    this.homeSections = const [],
    this.isLoading = false,
    this.isLoggedIn = false,
    this.error,
  });

  LibraryState copyWith({
    List<PlaylistItem>? playlists,
    List<Album>? albums,
    List<Track>? likedSongs,
    List<Map<String, dynamic>>? homeSections,
    bool? isLoading,
    bool? isLoggedIn,
    String? error,
    bool clearError = false,
  }) {
    return LibraryState(
      playlists: playlists ?? this.playlists,
      albums: albums ?? this.albums,
      likedSongs: likedSongs ?? this.likedSongs,
      homeSections: homeSections ?? this.homeSections,
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class LibraryNotifier extends StateNotifier<LibraryState> {
  final YtMusicService _ytMusic;

  LibraryNotifier({required YtMusicService ytMusic})
      : _ytMusic = ytMusic,
        super(LibraryState(isLoggedIn: ytMusic.isLoggedIn)) {
    if (ytMusic.isLoggedIn) {
      loadHomeSections();
    }
  }

  Future<void> loadHomeSections() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final sections = await _ytMusic.getHomeSections();
      if (mounted) {
        state = state.copyWith(
          homeSections: sections,
          isLoading: false,
          isLoggedIn: _ytMusic.isLoggedIn,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load home: $e',
        );
      }
    }
  }

  Future<void> loadPlaylists() async {
    // dart_ytmusic_api v1.3.6 does not have getLibraryPlaylists()
    // Playlist features will be available in a future API version
    if (mounted) state = state.copyWith(isLoading: false);
  }

  Future<void> loadLikedSongs() async {
    // dart_ytmusic_api v1.3.6 does not have getLikedSongs()
    // Liked songs will be available in a future API version
    if (mounted) state = state.copyWith(isLoading: false);
  }

  Future<List<Track>> searchSongs(String query) async {
    try {
      final results = await _ytMusic.searchSongs(query);
      return results.map((r) => _parseTrack(r)).toList();
    } catch (e) {
      debugPrint('LibraryNotifier: search error: $e');
      return [];
    }
  }

  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    try {
      final playlist = await _ytMusic.getPlaylist(playlistId);
      if (playlist == null) return [];

      final tracks = playlist['tracks'] as List<dynamic>? ?? [];
      return tracks.map((t) => _parseTrack(t as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('LibraryNotifier: getPlaylistTracks error: $e');
      return [];
    }
  }

  Future<List<Track>> getAlbumTracks(String albumId) async {
    try {
      final album = await _ytMusic.getAlbum(albumId);
      if (album == null) return [];

      final tracks = album['tracks'] as List<dynamic>? ?? [];
      return tracks.map((t) => _parseTrack(t as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('LibraryNotifier: getAlbumTracks error: $e');
      return [];
    }
  }

  Track _parseTrack(Map<String, dynamic> data) {
    final videoId = data['videoId'] as String? ?? '';
    return Track(
      id: data['id'] as String? ?? videoId,
      videoId: videoId,
      title: data['title'] as String? ?? 'Unknown',
      artist: _extractArtist(data),
      album: data['album'] as String?,
      albumArtUrl: data['thumbnails'] != null
          ? _bestThumbnail(data['thumbnails'])
          : null,
      duration: Duration(seconds: data['duration'] as int? ?? 0),
      artistId: data['artistId'] as String?,
      albumId: data['albumId'] as String?,
    );
  }

  String _extractArtist(Map<String, dynamic> data) {
    final artists = data['artists'] as List<dynamic>?;
    if (artists != null && artists.isNotEmpty) {
      final first = artists.first;
      if (first is String) return first;
      if (first is Map) return first['name'] as String? ?? 'Unknown Artist';
    }
    final artist = data['artist'] as String?;
    if (artist != null && artist.isNotEmpty) return artist;
    return 'Unknown Artist';
  }

  String? _bestThumbnail(dynamic thumbnails) {
    if (thumbnails == null) return null;
    if (thumbnails is List) {
      if (thumbnails.isEmpty) return null;
      thumbnails.sort((a, b) {
        final aRes = ((a as Map)['height'] ?? 0) as int;
        final bRes = ((b as Map)['height'] ?? 0) as int;
        return bRes.compareTo(aRes);
      });
      return (thumbnails.first as Map)['url'] as String?;
    }
    return null;
  }
}

final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  final ytMusic = ref.watch(ytMusicServiceProvider);
  return LibraryNotifier(ytMusic: ytMusic);
});
