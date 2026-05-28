import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dart_ytmusic_api/yt_music.dart' as yt;
import '../providers/settings_provider.dart';

class YtMusicService {
  yt.YTMusic? _api;
  bool _initialized = false;
  String _cookies = '';

  bool _loggedIn = false;
  bool get isLoggedIn => _loggedIn || _cookies.isNotEmpty;

  Future<void> initialize({String? cookies}) async {
    if (cookies != null) _cookies = cookies;
    if (_cookies.isNotEmpty) _loggedIn = true;

    if (_api == null) {
      _api = yt.YTMusic();
    }
    try {
      _api!.hasInitialized = false;
      await _api!.initialize(cookies: _cookies, gl: 'US', hl: 'en');
      _loggedIn = _cookies.isNotEmpty;
      _initialized = true;
    } catch (e) {
      _initialized = true;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  // ---------------------------------------------------------------------------
  //  Home
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getHomeSections() async {
    await _ensureInitialized();
    try {
      final sections = await _api!.getHomeSections();
      return sections.map((s) => _homeSectionToMap(s as dynamic)).toList().cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  //  Stream URL extraction — uses YT Music API directly (no native plugin)
  // ---------------------------------------------------------------------------

  Future<String?> getAudioStreamUrl(String videoId) async {
    await _ensureInitialized();
    try {
      final song = await _api!.getSong(videoId);

      final formats = <Map<String, dynamic>>[];
      for (final f in (song.formats as List<dynamic>? ?? [])) {
        formats.add(f as Map<String, dynamic>);
      }
      for (final f in (song.adaptiveFormats as List<dynamic>? ?? [])) {
        formats.add(f as Map<String, dynamic>);
      }

      formats.sort((a, b) {
        final aBitrate = (a['bitrate'] ?? a['averageBitrate'] ?? 0) as num;
        final bBitrate = (b['bitrate'] ?? b['averageBitrate'] ?? 0) as num;
        return bBitrate.compareTo(aBitrate);
      });

      for (final fmt in formats) {
        final url = fmt['url'] as String?;
        if (url != null && url.isNotEmpty) return url;
        final decodedUrl = fmt['signatureCipher'] as String?;
        if (decodedUrl != null && decodedUrl.isNotEmpty) return decodedUrl;
      }

      return null;
    } catch (e, stack) {
      debugPrint('YtMusicService: getAudioStreamUrl error: $e\n$stack');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  //  Search
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    await _ensureInitialized();
    try {
      final results = await _api!.searchSongs(query);
      return results.map((r) => _songToMap(r as dynamic)).toList().cast<Map<String, dynamic>>();
    } catch (e, stack) {
      debugPrint('YtMusicService: search error: $e\n$stack');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  //  Albums
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getAlbum(String albumId) async {
    await _ensureInitialized();
    try {
      final album = await _api!.getAlbum(albumId);
      return _albumToMap(album as dynamic);
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  //  Playlists
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getPlaylist(String playlistId) async {
    await _ensureInitialized();
    try {
      final playlist = await _api!.getPlaylist(playlistId);
      return _playlistToMap(playlist as dynamic);
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getPlaylistVideos(String playlistId) async {
    await _ensureInitialized();
    try {
      final videos = await _api!.getPlaylistVideos(playlistId);
      return videos.map((v) => _videoToMap(v as dynamic)).toList().cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  //  Artists
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getArtist(String artistId) async {
    await _ensureInitialized();
    try {
      final artist = await _api!.getArtist(artistId);
      return _artistToMap(artist as dynamic);
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getArtistAlbums(String artistId) async {
    await _ensureInitialized();
    try {
      final albums = await _api!.getArtistAlbums(artistId);
      return albums.map((a) => _albumDetailToMap(a as dynamic)).toList().cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  //  Up Next
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getUpNext(String videoId) async {
    await _ensureInitialized();
    try {
      final results = await _api!.getUpNexts(videoId);
      return results.map((r) => _upNextToMap(r as dynamic)).toList().cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  //  Auth
  // ---------------------------------------------------------------------------

  Future<bool> validateCookies() async {
    await _ensureInitialized();
    try {
      await _api!.getHomeSections();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    _loggedIn = false;
    _cookies = '';
    _initialized = false;
    _api = null;
  }

  // ===========================================================================
  //  Type converters: typed objects → Map<String, dynamic>
  // ===========================================================================

  static Map<String, dynamic> _thumbnail(dynamic t) => {
        'url': (t as dynamic).url,
        'width': t.width,
        'height': t.height,
      };

  static List<Map<String, dynamic>> _thumbnails(dynamic list) =>
      (list as List?)?.map((t) => _thumbnail(t as dynamic)).toList() ?? [];

  static Map<String, dynamic> _songToMap(dynamic s) => {
        'id': (s as dynamic).videoId,
        'videoId': s.videoId,
        'title': s.name,
        'artist': s.artist.name,
        'artistId': s.artist.artistId,
        'album': s.album?.name,
        'albumId': s.album?.albumId,
        'duration': s.duration ?? 0,
        'thumbnails': _thumbnails(s.thumbnails),
      };

  static Map<String, dynamic> _videoToMap(dynamic v) => {
        'id': (v as dynamic).videoId,
        'videoId': v.videoId,
        'title': v.title,
        'artist': v.artists is List
            ? (v.artists as List).map((a) => (a as dynamic).name).join(', ')
            : v.artist?.name ?? '',
        'duration': v.duration ?? 0,
        'thumbnails': _thumbnails(v.thumbnails),
      };

  static Map<String, dynamic> _albumDetailToMap(dynamic a) => {
        'id': (a as dynamic).albumId,
        'browseId': a.albumId,
        'playlistId': a.playlistId,
        'title': a.name,
        'artist': a.artist.name,
        'artistId': a.artist.artistId,
        'year': a.year,
        'thumbnails': _thumbnails(a.thumbnails),
      };

  static Map<String, dynamic> _albumToMap(dynamic a) => {
        'id': (a as dynamic).albumId,
        'browseId': a.albumId,
        'playlistId': a.playlistId,
        'title': a.name,
        'artist': a.artist.name,
        'artistId': a.artist.artistId,
        'year': a.year,
        'thumbnails': _thumbnails(a.thumbnails),
        'tracks': (a.songs as List).map((s) => _songToMap(s as dynamic)).toList(),
      };

  static Map<String, dynamic> _playlistToMap(dynamic p) => {
        'id': (p as dynamic).playlistId,
        'browseId': p.playlistId,
        'title': p.name,
        'artist': p.artist.name,
        'artistId': p.artist.artistId,
        'videoCount': p.videoCount,
        'thumbnails': _thumbnails(p.thumbnails),
      };

  static Map<String, dynamic> _artistToMap(dynamic a) => {
        'id': (a as dynamic).artistId,
        'browseId': a.artistId,
        'artistId': a.artistId,
        'title': a.name,
        'thumbnails': _thumbnails(a.thumbnails),
        'topSongs': (a.topSongs as List).map((s) => _songToMap(s as dynamic)).toList(),
        'topAlbums': (a.topAlbums as List).map((al) => _albumDetailToMap(al as dynamic)).toList(),
        'topSingles': (a.topSingles as List).map((s) => _albumDetailToMap(s as dynamic)).toList(),
      };

  static Map<String, dynamic> _upNextToMap(dynamic u) => {
        'id': (u as dynamic).videoId,
        'videoId': u.videoId,
        'title': u.title,
        'artist': u.artists.name,
        'artistId': u.artists.artistId,
        'album': u.album?.name,
        'albumId': u.album?.albumId,
        'duration': u.duration,
        'thumbnails': _thumbnails(u.thumbnails),
      };

  static Map<String, dynamic> _homeSectionToMap(dynamic s) => {
        'title': (s as dynamic).title,
        'contents': (s.contents as List).map((c) => _contentToMap(c as dynamic)).toList(),
      };

  static Map<String, dynamic> _contentToMap(dynamic item) {
    try {
      return _songToMap(item as dynamic);
    } catch (_) {}
    try {
      return _albumDetailToMap(item as dynamic);
    } catch (_) {}
    try {
      return _albumToMap(item as dynamic);
    } catch (_) {}
    try {
      return _playlistToMap(item as dynamic);
    } catch (_) {}
    try {
      return _artistToMap(item as dynamic);
    } catch (_) {}
    return {'title': item.toString(), 'contents': <dynamic>[]};
  }
}

final ytMusicServiceProvider = Provider<YtMusicService>((ref) {
  final cookies = ref.watch(settingsProvider.select((s) => s.cookies));
  final service = YtMusicService();
  service.initialize(cookies: cookies);
  return service;
});
