import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import '../models/track.dart';

/// Manages Chromecast / Google Cast integration.
///
/// Uses flutter_chrome_cast to discover Cast devices, connect,
/// and stream audio to TVs, speakers, and Android TV devices.
///
/// State: castEnabled (bool), deviceName (String?), connected (bool)
class CastService {
  /// Whether the Cast SDK is available on this device.
  bool get isCastAvailable => defaultTargetPlatform == TargetPlatform.android;

  /// Whether we're currently connected to a Cast device.
  bool _connected = false;
  bool get connected => _connected;

  /// Name of the connected Cast device.
  String? _deviceName;
  String? get deviceName => _deviceName;

  /// Current cast volume (0.0 - 1.0).
  double _volume = 1.0;
  double get volume => _volume;

  /// Callbacks for UI updates.
  VoidCallback? onConnectionChange;
  VoidCallback? onDeviceListChange;

  /// Internal device list cache.
  List<GoogleCastDevice> _devices = [];
  List<GoogleCastDevice> get devices => List.unmodifiable(_devices);

  /// Stream subscriptions for cleanup.
  dynamic _devicesSub;
  dynamic _sessionSub;

  /// Initialize the Cast SDK.
  /// Call once at app startup.
  Future<void> initialize() async {
    if (!isCastAvailable) return;

    try {
      const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
      final options = GoogleCastOptionsAndroid(appId: appId);
      GoogleCastContext.instance.setSharedInstanceWithOptions(options);

      // Listen for device discovery
      _devicesSub = GoogleCastDiscoveryManager.instance.devicesStream.listen((deviceList) {
        _devices = deviceList;
        onDeviceListChange?.call();
      });

      // Listen for session changes
      _sessionSub = GoogleCastSessionManager.instance.currentSessionStream.listen((session) {
        final wasConnected = _connected;
        _connected = session != null;
        _deviceName = session?.device?.friendlyName;

        if (wasConnected != _connected) {
          onConnectionChange?.call();
        }
      });

      debugPrint('CastService: initialized with Cast SDK');
    } catch (e) {
      debugPrint('CastService: init error: $e');
    }
  }

  /// Start scanning for Cast devices.
  Future<void> startDiscovery() async {
    if (!isCastAvailable) return;
    try {
      GoogleCastDiscoveryManager.instance.startDiscovery();
      debugPrint('CastService: scanning for devices...');
    } catch (e) {
      debugPrint('CastService: discovery error: $e');
    }
  }

  /// Stop scanning for Cast devices.
  Future<void> stopDiscovery() async {
    if (!isCastAvailable) return;
    try {
      GoogleCastDiscoveryManager.instance.stopDiscovery();
    } catch (e) {
      debugPrint('CastService: stop discovery error: $e');
    }
  }

  /// Get list of available Cast devices.
  Future<List<GoogleCastDevice>> getAvailableDevices() async {
    if (!isCastAvailable) return [];
    return _devices;
  }

  /// Connect to a Cast device.
  Future<bool> connectToDevice(GoogleCastDevice device) async {
    if (!isCastAvailable) return false;

    try {
      await GoogleCastSessionManager.instance.startSessionWithDevice(device);
      _connected = true;
      _deviceName = device.friendlyName;
      onConnectionChange?.call();
      return true;
    } catch (e) {
      debugPrint('CastService: connect error: $e');
      return false;
    }
  }

  /// Disconnect from the current Cast device.
  Future<void> disconnect() async {
    if (!_connected) return;

    try {
      await GoogleCastSessionManager.instance.endSessionAndStopCasting();
      _connected = false;
      _deviceName = null;
      onConnectionChange?.call();
    } catch (e) {
      debugPrint('CastService: disconnect error: $e');
    }
  }

  /// Cast media to the connected device.
  ///
  /// [track] — the track to cast
  /// [streamUrl] — the direct audio stream URL
  /// [position] — optional position to start from (for resume)
  Future<void> castTrack(Track track, String streamUrl, {Duration? position}) async {
    if (!_connected) return;

    try {
      // Build media metadata
      final metadata = GoogleCastMusicMediaMetadata(
        title: track.title,
        artist: track.artist,
        albumName: track.album ?? '',
        images: track.albumArtUrl != null
            ? [
                GoogleCastImage(
                  url: Uri.parse(track.albumArtUrl!),
                  height: 480,
                  width: 480,
                ),
              ]
            : [],
      );

      // Build media information
      final mediaInfo = GoogleCastMediaInformation(
        contentId: track.id,
        streamType: CastMediaStreamType.buffered,
        contentUrl: Uri.parse(streamUrl),
        contentType: 'audio/mp4',
        metadata: metadata,
      );

      // Load and play on the Cast device
      await GoogleCastRemoteMediaClient.instance.loadMedia(
        mediaInfo,
        autoPlay: true,
        playPosition: position ?? Duration.zero,
        playbackRate: 1.0,
      );

      debugPrint('CastService: casting ${track.title}');
    } catch (e) {
      debugPrint('CastService: cast error: $e');
    }
  }

  /// Set the cast device volume.
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (!_connected) return;

    try {
      GoogleCastSessionManager.instance.setDeviceVolume(_volume);
    } catch (e) {
      debugPrint('CastService: volume error: $e');
    }
  }

  /// Toggle play/pause on the Cast receiver.
  Future<void> togglePlayPause() async {
    if (!_connected) return;
    try {
      final isPlaying = GoogleCastRemoteMediaClient.instance.mediaStatus?.playerState ==
          CastMediaPlayerState.playing;
      if (isPlaying) {
        await GoogleCastRemoteMediaClient.instance.pause();
      } else {
        await GoogleCastRemoteMediaClient.instance.play();
      }
    } catch (e) {
      debugPrint('CastService: play/pause error: $e');
    }
  }

  /// Seek on the Cast receiver.
  Future<void> seek(Duration position) async {
    if (!_connected) return;
    try {
      await GoogleCastRemoteMediaClient.instance.seek(
        GoogleCastMediaSeekOption(position: position),
      );
    } catch (e) {
      debugPrint('CastService: seek error: $e');
    }
  }

  /// Dispose — clean up streams and disconnect.
  void dispose() {
    try {
      _devicesSub?.cancel();
      _sessionSub?.cancel();
    } catch (_) {}
    stopDiscovery();
    disconnect();
  }
}

// =======================================================================
//  Riverpod provider
// =======================================================================

final castServiceProvider = Provider<CastService>((ref) {
  final service = CastService();
  ref.onDispose(() => service.dispose());
  return service;
});
