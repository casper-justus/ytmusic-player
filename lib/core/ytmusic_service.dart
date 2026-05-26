import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dart_ytmusic_api/yt_music.dart' as yt;

/// Wraps dart_ytmusic_api to provide YouTube Music data:
/// search, home feed, playlists, albums, artists, and account login.
class YtMusicService {
  late final yt.YTMusic _api;
  bool _initialized = false;
  bool _loggedIn = false;

  /// Whether the user is logged in with YouTube Music cookies.
  bool get isLoggedIn => _loggedIn;

  /// Initialize the YT Music API client.
  ///
  /// Pass [cookies] to authenticate as a YouTube Music account.
  /// Without cookies, only public data (search, basic metadata) is available.
  Future<void> initialize({String? cookies}) async {
    if (_initialized) return;

    _api = yt.YTMusic();
    await _api.initialize(cookies: cookies ?? '');

    _loggedIn = (cookies != null && cookies.isNotEmpty);
    _initialized = true;
  }

  /// Ensure initialized lazily.
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  // =======================================================================
  //  Home / Browse
  // =======================================================================

  /// Get the YouTube Music home screen sections.
  /// Returns a list of section maps with titles and content items.
  Future<List<Map<String, dynamic>>> getHomeSections() async {
    await _ensureInitialized();
    try {
      final sections = await _api.getHomeSections();
      return sections.map((s) => s as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  // =======================================================================
  //  Search
  // =======================================================================

  /// Search for songs on YouTube Music.
  Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    await _ensureInitialized();
    try {
      final results = await _api.searchSongs(query);
      return results.map((r) => r as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  /// Search across all categories (songs, videos, albums, artists, playlists).
  Future<List<Map<String, dynamic>>> searchAll(String query) async {
    await _ensureInitialized();
    try {
      final results = await _api.search(query);
      return results.map((r) => r as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  // =======================================================================
  //  Albums
  // =======================================================================

  /// Get full album details including track list.
  Future<Map<String, dynamic>?> getAlbum(String albumId) async {
    await _ensureInitialized();
    try {
      return await _api.getAlbum(albumId) as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  // =======================================================================
  //  Playlists
  // =======================================================================

  /// Get playlist details with all tracks.
  Future<Map<String, dynamic>?> getPlaylist(String playlistId) async {
    await _ensureInitialized();
    try {
      return await _api.getPlaylist(playlistId) as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Note: library playlists and liked songs are not available
  /// in dart_ytmusic_api v1.3.6. These features require the
  /// ytmusicapi_dart package or direct API calls.

  // =======================================================================
  //  Artists
  // =======================================================================

  /// Get artist details including top songs and related content.
  Future<Map<String, dynamic>?> getArtist(String artistId) async {
    await _ensureInitialized();
    try {
      return await _api.getArtist(artistId) as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Get artist's albums.
  Future<List<Map<String, dynamic>>> getArtistAlbums(String artistId) async {
    await _ensureInitialized();
    try {
      final albums = await _api.getArtistAlbums(artistId);
      return albums.map((a) => a as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  // =======================================================================
  //  Radio / Mixes
  // =======================================================================

  /// Get "Up Next" suggestions (radio based on a song).
  /// Used to generate infinite playback queues.
  Future<List<Map<String, dynamic>>> getUpNext(String videoId) async {
    await _ensureInitialized();
    try {
      final results = await _api.getUpNexts(videoId);
      return results.map((r) => r as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  /// Note: mix/radio generation is not available in dart_ytmusic_api v1.3.6.
  /// Use [getUpNext] for suggested next tracks instead.

  // =======================================================================
  //  Auth helpers
  // =======================================================================

  /// Get the currently configured cookies (for persistence).
  String? getCurrentCookies() {
    // This would read back from secure storage if implemented.
    // dart_ytmusic_api stores cookies internally.
    return null;
  }

  /// Validate whether cookies are still working.
  Future<bool> validateCookies() async {
    await _ensureInitialized();
    try {
      await _api.getHomeSections();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Log out by clearing cookies.
  Future<void> logout() async {
    _loggedIn = false;
    _initialized = false;
  }
}

// =======================================================================
//  Riverpod provider
// =======================================================================

final ytMusicServiceProvider = Provider<YtMusicService>((ref) {
  return YtMusicService();
});
