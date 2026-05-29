import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dart_ytmusic_api/yt_music.dart' as yt;
import 'package:dart_ytmusic_api/utils/traverse.dart';
import 'package:dart_ytmusic_api/utils/filters.dart';
import '../providers/settings_provider.dart';

class YtMusicService {
  yt.YTMusic? _api;
  bool _initialized = false;
  String _cookies = '';

  bool _loggedIn = false;
  bool get isLoggedIn => _loggedIn || _cookies.isNotEmpty;

  bool _cookiesExpired = false;
  bool get cookiesExpired => _cookiesExpired;
  void clearCookiesExpired() => _cookiesExpired = false;

  Future<void> initialize({String? cookies}) async {
    if (cookies != null) _cookies = cookies;
    if (_cookies.isNotEmpty) _loggedIn = true;

    if (_api == null) {
      _api = yt.YTMusic();
    }
    try {
      _api!.hasInitialized = false;
      await _api!.initialize(cookies: _cookies, gl: 'US', hl: 'en');
      
      if (_cookies.isNotEmpty) {
        for (final c in _cookies.split('; ')) {
          try {
            final cookie = Cookie.fromSetCookieValue(c);
            _api!.cookieJar.saveFromResponse(
              Uri.parse('https://music.youtube.com/'),
              [cookie],
            );
          } catch (_) {}
        }
      }

      _loggedIn = _cookies.isNotEmpty;
      _initialized = true;
    } catch (e) {
      debugPrint('YtMusicService: initialize error: ${e}');
      _initialized = true;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  Future<List<Map<String, dynamic>>> getHomeSections() async {
    await _ensureInitialized();
    try {
      final sections = await _api!.getHomeSections();
      debugPrint('YtMusicService: got ${sections.length} home sections');
      _cookiesExpired = false;
      final result = sections
          .map((s) => _homeSectionToMap(s as dynamic))
          .toList()
          .cast<Map<String, dynamic>>();
      debugPrint('YtMusicService: mapped ${result.length} home sections');
      // Detect expired cookies: if logged in but got empty results, cookies may be expired
      if (_cookies.isNotEmpty && result.isEmpty) {
        debugPrint('YtMusicService: got empty home sections despite having cookies - may be expired');
        _cookiesExpired = true;
      }
      for (final section in result) {
        debugPrint(
            '  section "${section["title"]}": ${(section["contents"] as List).length} items');
      }
      return result;
    } catch (e, stack) {
      debugPrint('YtMusicService: getHomeSections error: ${e}');
      debugPrint(stack.toString());
      return [];
    }
  }

  Future<String?> getAudioStreamUrl(String videoId) async {
    await _ensureInitialized();
    try {
      final song = await _api!.getSong(videoId);

      final formats = <dynamic>[];
      formats.addAll(song.formats);
      formats.addAll(song.adaptiveFormats);

      // Sort by bitrate descending to get best quality first
      formats.sort((a, b) {
        final aBitrate = _fmtBitrate(a);
        final bBitrate = _fmtBitrate(b);
        return bBitrate.compareTo(aBitrate);
      });

      for (final fmt in formats) {
        // Try direct URL first
        final url = _fmtStr(fmt, 'url');
        if (url != null && url.isNotEmpty) {
          debugPrint('YtMusicService: found direct URL for ${videoId}');
          return url;
        }

        // Handle signatureCipher: extract URL + signature from cipher string
        // Format: "url=https://...&sp=sig&sig=ABC123..."
        final cipher = _fmtStr(fmt, 'signatureCipher');
        if (cipher != null && cipher.isNotEmpty) {
          try {
            final params = Uri.splitQueryString(cipher);
            final cipherUrl = params['url'];
            final sig = params['sig'];
            final sp = params['sp'] ?? 'sig';
            if (cipherUrl != null && sig != null && cipherUrl.isNotEmpty) {
              final uri = Uri.parse(cipherUrl);
              final resolved = uri.replace(queryParameters: {
                ...uri.queryParameters,
                sp: sig,
              }).toString();
              debugPrint('YtMusicService: resolved signatureCipher for ${videoId}');
              return resolved;
            }
          } catch (e) {
            debugPrint('YtMusicService: failed to parse signatureCipher for ${videoId}: ${e}');
          }
        }
      }

      debugPrint(
          'YtMusicService: no stream URL for videoId=${videoId} (${formats.length} formats)');
      return null;
    } catch (e, stack) {
      debugPrint('YtMusicService: getAudioStreamUrl error: ${e}');
      debugPrint(stack.toString());
      return null;
    }
  }

  /// Try to get audio stream URL using a different InnerTube client (fallback).
  /// WEB_REMIX might not return direct URLs, but TVHTML5 often does.
  Future<String?> getAudioStreamUrlFallback(String videoId) async {
    await _ensureInitialized();
    try {
      // Use the TVHTML5 client which often returns direct URLs for audio
      final response = await _api!.constructRequest('player', body: {
        'videoId': videoId,
        'playbackContext': {
          'contentPlaybackContext': {
            'signatureTimestamp': 19865,
          },
        },
      }, query: {
        'client': 'TVHTML5',
      });

      final streamingData = response['streamingData'] as Map?;
      if (streamingData == null) return null;

      final allFormats = <dynamic>[];
      final formats = streamingData['formats'] as List? ?? [];
      final adaptiveFormats = streamingData['adaptiveFormats'] as List? ?? [];
      allFormats.addAll(formats);
      allFormats.addAll(adaptiveFormats);

      for (final fmt in allFormats) {
        if (fmt is Map) {
          final url = fmt['url'] as String?;
          if (url != null && url.isNotEmpty) return url;

          final cipher = fmt['signatureCipher'] as String?;
          if (cipher != null && cipher.isNotEmpty) {
            try {
              final params = Uri.splitQueryString(cipher);
              final cipherUrl = params['url'];
              final sig = params['sig'];
              final sp = params['sp'] ?? 'sig';
              if (cipherUrl != null && sig != null && cipherUrl.isNotEmpty) {
                final uri = Uri.parse(cipherUrl);
                return uri.replace(queryParameters: {
                  ...uri.queryParameters,
                  sp: sig,
                }).toString();
              }
            } catch (_) {}
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('YtMusicService: getAudioStreamUrlFallback error: ${e}');
      return null;
    }
  }

  num _fmtBitrate(dynamic f) {
    try {
      return (f['bitrate'] ?? f['averageBitrate'] ?? 0) as num;
    } catch (_) {}
    try {
      return (f.bitrate ?? f.averageBitrate ?? 0) as num;
    } catch (_) {}
    return 0;
  }

  String? _fmtStr(dynamic f, String key) {
    try {
      if (f is Map) {
        final v = f[key];
        if (v is String && v.isNotEmpty) return v;
        return v?.toString();
      }
    } catch (_) {}
    try {
      return (f as dynamic)[key]?.toString();
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    await _ensureInitialized();
    try {
      final results = await _api!.searchSongs(query);
      debugPrint(
          'YtMusicService: search "${query}" returned ${results.length} results');
      return results
          .map((r) => _songToMap(r as dynamic))
          .toList()
          .cast<Map<String, dynamic>>();
    } catch (e, stack) {
      debugPrint('YtMusicService: search error: ${e}');
      debugPrint(stack.toString());
      return [];
    }
  }

  Future<Map<String, dynamic>?> getAlbum(String albumId) async {
    await _ensureInitialized();
    try {
      final album = await _api!.getAlbum(albumId);
      return _albumToMap(album as dynamic);
    } catch (e) {
      debugPrint('YtMusicService: getAlbum error: ${e}');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getPlaylist(String playlistId) async {
    await _ensureInitialized();
    try {
      final playlist = await _api!.getPlaylist(playlistId);
      return _playlistFullToMap(playlist as dynamic);
    } catch (e) {
      debugPrint('YtMusicService: getPlaylist error: ${e}');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getPlaylistVideos(
      String playlistId) async {
    await _ensureInitialized();
    try {
      final videos = await _api!.getPlaylistVideos(playlistId);
      debugPrint(
          'YtMusicService: getPlaylistVideos returned ${videos.length} videos');
      return videos
          .map((v) => _videoToMap(v as dynamic))
          .toList()
          .cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('YtMusicService: getPlaylistVideos error: ${e}');
      return [];
    }
  }

  /// Get playlist videos with full metadata (including album) using raw browse response.
  /// Unlike getPlaylistVideos() which returns VideoDetailed (no album fields), this
  /// parses the raw InnerTube response to extract album info from flex columns.
  Future<List<Map<String, dynamic>>> getPlaylistVideosFull(
      String playlistId) async {
    await _ensureInitialized();
    try {
      final browseId = playlistId.startsWith('PL') ? 'VL$playlistId' : playlistId;
      final response = await _api!.constructRequest('browse', body: {
        'browseId': browseId,
      });

      final items = traverseList(
        response,
        ['musicPlaylistShelfRenderer', 'musicResponsiveListItemRenderer'],
      );

      // Handle continuation tokens for paginated playlists
      dynamic continuation = traverse(response, ['continuation']);
      if (continuation is List) {
        continuation = continuation.isNotEmpty ? continuation[0] : null;
      }
      while (continuation != null) {
        final moreData = await _api!.constructRequest(
          'browse',
          query: {'continuation': continuation.toString()},
        );
        items.addAll(
          traverseList(moreData, ['musicResponsiveListItemRenderer']),
        );
        continuation = traverse(moreData, ['continuation']);
        if (continuation is List) {
          continuation = continuation.isNotEmpty ? continuation[0] : null;
        }
      }

      debugPrint(
          'YtMusicService: getPlaylistVideosFull found ${items.length} items');
      return items
          .map((item) => _responsiveItemToSong(item as dynamic))
          .toList();
    } catch (e, stack) {
      debugPrint('YtMusicService: getPlaylistVideosFull error: ${e}');
      debugPrint(stack.toString());
      // Fall back to typed API
      return getPlaylistVideos(playlistId);
    }
  }

  Future<Map<String, dynamic>?> getArtist(String artistId) async {
    await _ensureInitialized();
    try {
      final artist = await _api!.getArtist(artistId);
      return _artistToMap(artist as dynamic);
    } catch (e) {
      debugPrint('YtMusicService: getArtist error: ${e}');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getArtistAlbums(
      String artistId) async {
    await _ensureInitialized();
    try {
      final albums = await _api!.getArtistAlbums(artistId);
      return albums
          .map((a) => _albumDetailToMap(a as dynamic))
          .toList()
          .cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('YtMusicService: getArtistAlbums error: ${e}');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUpNext(String videoId) async {
    await _ensureInitialized();
    try {
      final results = await _api!.getUpNexts(videoId);
      return results
          .map((r) => _upNextToMap(r as dynamic))
          .toList()
          .cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('YtMusicService: getUpNext error: ${e}');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getLibraryPlaylists() async {
    await _ensureInitialized();
    try {
      final response = await _api!.constructRequest('browse', body: {
        'browseId': 'FEmusic_library_playlists',
      });
      debugPrint('YtMusicService: library playlists keys: ${response.keys}');
      final items =
          traverseList(response, ['musicResponsiveListItemRenderer']);
      debugPrint('YtMusicService: found ${items.length} playlist items');
      // Detect expired cookies
      if (_cookies.isNotEmpty && items.isEmpty) {
        debugPrint('YtMusicService: got empty library playlists despite having cookies - may be expired');
        _cookiesExpired = true;
      }
      return items
          .map((item) => _responsiveItemToPlaylist(item as dynamic))
          .toList();
    } catch (e, stack) {
      debugPrint('YtMusicService: getLibraryPlaylists error: ${e}');
      debugPrint(stack.toString());
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getLikedSongs() async {
    await _ensureInitialized();
    try {
      final response = await _api!.constructRequest('browse', body: {
        'browseId': 'FEmusic_liked_videos',
      });
      debugPrint('YtMusicService: liked songs keys: ${response.keys}');
      final items =
          traverseList(response, ['musicResponsiveListItemRenderer']);
      debugPrint('YtMusicService: found ${items.length} liked song items');
      // Detect expired cookies
      if (_cookies.isNotEmpty && items.isEmpty) {
        debugPrint('YtMusicService: got empty liked songs despite having cookies - may be expired');
        _cookiesExpired = true;
      }
      return items
          .map((item) => _responsiveItemToSong(item as dynamic))
          .toList();
    } catch (e, stack) {
      debugPrint('YtMusicService: getLikedSongs error: ${e}');
      debugPrint(stack.toString());
      return [];
    }
  }

  Future<bool> validateCookies() async {
    await _ensureInitialized();
    try {
      await _api!.getHomeSections();
      return true;
    } catch (e) {
      debugPrint('YtMusicService: validateCookies error: ${e}');
      return false;
    }
  }

  Future<void> logout() async {
    _loggedIn = false;
    _cookies = '';
    _initialized = false;
    _api = null;
  }

  static List<dynamic> _flexRuns(dynamic item) =>
      traverseList(item, ['flexColumns', 'runs'])
          .expand((e) => e is List ? e : [e])
          .toList();

  static Map<String, dynamic> _responsiveItemToPlaylist(dynamic item) {
    final runs = _flexRuns(item);
    final title =
        runs.isNotEmpty ? traverseString(runs[0], ['text']) ?? '' : '';
    final subtitle =
        runs.length > 1 ? traverseString(runs[1], ['text']) ?? '' : '';

    int trackCount = 0;
    final countMatch = RegExp(r'^(\d+)').firstMatch(subtitle);
    if (countMatch != null) {
      trackCount = int.tryParse(countMatch.group(1) ?? '0') ?? 0;
    }

    return {
      'id':
          traverseString(item, ['navigationEndpoint', 'browseId']) ?? '',
      'title': title,
      'trackCount': trackCount,
      'imageUrl':
          _bestThumbnailUrl(traverseList(item, ['thumbnails'])),
    };
  }

  static Map<String, dynamic> _responsiveItemToSong(dynamic item) {
    final runs = _flexRuns(item);
    final titleEntry = runs.firstWhere(
        (r) => isTitle(r),
        orElse: () => runs.isNotEmpty ? runs[0] : null);
    final artistEntry =
        runs.firstWhere((r) => isArtist(r), orElse: () => null);
    final albumEntry =
        runs.firstWhere((r) => isAlbum(r), orElse: () => null);
    final durationEntry = runs.firstWhere(
        (r) => isDuration(r) && r != titleEntry,
        orElse: () => null);

    return {
      'id': traverseString(
                  item, ['playlistItemData', 'videoId']) ??
              traverseString(
                  item, ['navigationEndpoint', 'watchEndpoint', 'videoId']) ??
          '',
      'videoId': traverseString(
                  item, ['playlistItemData', 'videoId']) ??
              traverseString(
                  item, ['navigationEndpoint', 'watchEndpoint', 'videoId']) ??
          '',
      'title': traverseString(titleEntry, ['text']) ?? '',
      'artist': traverseString(artistEntry, ['text']) ?? '',
      'artistId': traverseString(artistEntry, ['browseId']),
      'album': traverseString(albumEntry, ['text']),
      'albumId': traverseString(albumEntry, ['browseId']),
      'duration':
          _parseDurationSeconds(durationEntry?['text'] as String?),
      'thumbnails': traverseList(item, ['thumbnails'])
          .map((t) => _thumbnail(t))
          .toList(),
    };
  }

  static int _parseDurationSeconds(String? text) {
    if (text == null) return 0;
    final parts = text.split(':');
    if (parts.length == 2) {
      return (int.tryParse(parts[0]) ?? 0) * 60 +
          (int.tryParse(parts[1]) ?? 0);
    } else if (parts.length == 3) {
      return (int.tryParse(parts[0]) ?? 0) * 3600 +
          (int.tryParse(parts[1]) ?? 0) * 60 +
          (int.tryParse(parts[2]) ?? 0);
    }
    return 0;
  }

  static String? _bestThumbnailUrl(List thumbnails) {
    if (thumbnails.isEmpty) return null;
    String? best;
    int bestH = 0;
    for (final t in thumbnails) {
      if (t is Map) {
        final url = t['url'] as String?;
        final h = (t['height'] ?? 0) as int;
        if (url != null && h > bestH) {
          bestH = h;
          best = url;
        }
      }
    }
    return best;
  }

  static Map<String, dynamic> _thumbnail(dynamic t) => {
        'url': t is Map ? t['url'] : (t as dynamic).url,
        'width': t is Map ? t['width'] : (t as dynamic).width,
        'height': t is Map ? t['height'] : (t as dynamic).height,
      };

  static List<Map<String, dynamic>> _thumbnails(dynamic list) =>
      (list as List?)?.map((t) => _thumbnail(t as dynamic)).toList() ?? [];

  static Map<String, dynamic> _songToMap(dynamic s) => {
        'id': (s as dynamic).videoId,
        'videoId': s.videoId,
        'title': s.name,
        'artist': s.artist?.name ?? "Unknown Artist",
        'artistId': s.artist?.artistId,
        'album': s.album?.name,
        'albumId': s.album?.albumId,
        'duration': s.duration ?? 0,
        'thumbnails': _thumbnails(s.thumbnails),
      };

  static Map<String, dynamic> _videoToMap(dynamic v) => {
        'id': (v as dynamic).videoId,
        'videoId': v.videoId,
        'title': v.name,
        'artist': v.artist?.name ?? "Unknown Artist",
        'artistId': v.artist?.artistId,
        // VideoDetailed has no album field - include with fallback
        'album': null,
        'albumId': null,
        'duration': v.duration ?? 0,
        'thumbnails': _thumbnails(v.thumbnails),
      };

  static Map<String, dynamic> _albumDetailToMap(dynamic a) => {
        'id': (a as dynamic).albumId,
        'browseId': a.albumId,
        'playlistId': a.playlistId,
        'title': a.name,
        'artist': a.artist?.name ?? "Unknown Artist",
        'artistId': a.artist?.artistId,
        'year': a.year,
        'thumbnails': _thumbnails(a.thumbnails),
      };

  static Map<String, dynamic> _albumToMap(dynamic a) => {
        'id': (a as dynamic).albumId,
        'browseId': a.albumId,
        'playlistId': a.playlistId,
        'title': a.name,
        'artist': a.artist?.name ?? "Unknown Artist",
        'artistId': a.artist?.artistId,
        'year': a.year,
        'thumbnails': _thumbnails(a.thumbnails),
        'tracks': (a.songs as List)
            .map((s) => _songToMap(s as dynamic))
            .toList(),
      };

  static Map<String, dynamic> _playlistFullToMap(dynamic p) {
    int vCount = 0;
    try {
      vCount = (p as dynamic).videoCount ?? 0;
    } catch (_) {}
    
    return {
      'id': (p as dynamic).playlistId,
      'browseId': p.playlistId,
      'title': p.name,
      'artist': p.artist?.name ?? "Unknown Artist",
      'artistId': p.artist?.artistId,
      'videoCount': vCount,
      'thumbnails': _thumbnails(p.thumbnails),
    };
  }

  static Map<String, dynamic> _artistToMap(dynamic a) => {
        'id': (a as dynamic).artistId,
        'browseId': a.artistId,
        'title': a.name,
        'thumbnails': _thumbnails(a.thumbnails),
        'topSongs': (a.topSongs as List)
            .map((s) => _songToMap(s as dynamic))
            .toList(),
        'topAlbums': (a.topAlbums as List)
            .map((al) => _albumDetailToMap(al as dynamic))
            .toList(),
        'topSingles': (a.topSingles as List)
            .map((s) => _albumDetailToMap(s as dynamic))
            .toList(),
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

  static Map<String, dynamic> _homeSectionToMap(dynamic s) {
    try {
      var contents = <dynamic>[];
      try {
        contents = (s.contents as List).toList();
      } catch (_) {}
      return {
        'title': (s as dynamic).title?.toString() ?? '',
        'contents':
            contents.map((c) => _contentToMap(c as dynamic)).toList(),
      };
    } catch (e) {
      debugPrint('YtMusicService: _homeSectionToMap error: ${e}');
      return {'title': '', 'contents': <dynamic>[]};
    }
  }

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
      return _playlistFullToMap(item as dynamic);
    } catch (_) {}
    try {
      return _artistToMap(item as dynamic);
    } catch (_) {}
    debugPrint(
        'YtMusicService: _contentToMap could not map item type=${item.runtimeType}');
    return {'title': item.toString(), 'contents': <dynamic>[]};
  }
}

final ytMusicServiceProvider = Provider<YtMusicService>((ref) {
  final cookies = ref.watch(settingsProvider.select((s) => s.cookies));
  final service = YtMusicService();
  service.initialize(cookies: cookies);
  return service;
});
