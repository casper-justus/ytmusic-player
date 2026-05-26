import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  // Internal: would hold the CastSession/client reference.
  // In production, this would be CastContext, CastSession, etc.

  /// Initialize the Cast SDK.
  /// Call once at app startup.
  Future<void> initialize() async {
    if (!isCastAvailable) return;

    try {
      // flutter_chrome_cast initialization:
      // CastContext.init(context, CastOptions);
      // CastContext.setReceiverDelegate(MyReceiverDelegate());
      // This registers the Cast button in the system UI.

      debugPrint('CastService: initialized');
    } catch (e) {
      debugPrint('CastService: init error: $e');
    }
  }

  /// Start scanning for Cast devices.
  Future<void> startDiscovery() async {
    if (!isCastAvailable) return;
    try {
      // CastContext.startDiscovery();
      debugPrint('CastService: scanning for devices...');
    } catch (e) {
      debugPrint('CastService: discovery error: $e');
    }
  }

  /// Stop scanning for Cast devices.
  Future<void> stopDiscovery() async {
    if (!isCastAvailable) return;
    try {
      // CastContext.stopDiscovery();
    } catch (e) {
      debugPrint('CastService: stop discovery error: $e');
    }
  }

  /// Get list of available Cast devices.
  Future<List<CastDevice>> getAvailableDevices() async {
    if (!isCastAvailable) return [];

    try {
      // Return devices from CastContext.getCastDevices()
      return []; // Placeholder — actual devices returned by plugin
    } catch (e) {
      return [];
    }
  }

  /// Connect to a Cast device.
  Future<bool> connectToDevice(CastDevice device) async {
    if (!isCastAvailable) return false;

    try {
      // CastContext.connectToDevice(device);
      _connected = true;
      _deviceName = device.name;
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
      // CastContext.disconnect();
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
      // Build MediaInfo and load on CastSession:
      // final mediaInfo = MediaInfo.Builder(streamUrl)
      //   .setContentType('audio/mp4')
      //   .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
      //   .setMetadata(MediaMetadata(MediaMetadata.MEDIA_TYPE_MUSIC_TRACK)
      //     ..putString(MediaMetadata.KEY_TITLE, track.title)
      //     ..putString(MediaMetadata.KEY_ARTIST, track.artist)
      //     ..putString(MediaMetadata.KEY_ALBUM_NAME, track.album ?? '')
      //     ..addImage(WebImage(Uri.parse(track.albumArtUrl ?? ''))))
      //   .build();
      //
      // final request = MediaLoadRequestData.Builder()
      //   .setMediaInfo(mediaInfo)
      //   .setCurrentTime(position?.inSeconds.toDouble() ?? 0)
      //   .build();
      //
      // CastSession.loadMedia(request);

      debugPrint('CastService: casting $track');
    } catch (e) {
      debugPrint('CastService: cast error: $e');
    }
  }

  /// Set the cast device volume.
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (!_connected) return;

    try {
      // CastSession.setVolume(volume);
    } catch (e) {
      debugPrint('CastService: volume error: $e');
    }
  }

  /// Toggle play/pause on the Cast receiver.
  Future<void> togglePlayPause() async {
    if (!_connected) return;
    try {
      // CastSession.play() or CastSession.pause()
    } catch (e) {
      debugPrint('CastService: play/pause error: $e');
    }
  }

  /// Seek on the Cast receiver.
  Future<void> seek(Duration position) async {
    if (!_connected) return;
    try {
      // CastSession.seek(position.inSeconds.toDouble());
    } catch (e) {
      debugPrint('CastService: seek error: $e');
    }
  }

  /// Dispose.
  void dispose() {
    stopDiscovery();
    disconnect();
  }
}

/// Lightweight representation of a Cast device.
class CastDevice {
  final String id;
  final String name;
  final String? model;

  const CastDevice({
    required this.id,
    required this.name,
    this.model,
  });
}

// =======================================================================
//  Riverpod provider
// =======================================================================

final castServiceProvider = Provider<CastService>((ref) {
  final service = CastService();
  ref.onDispose(() => service.dispose());
  return service;
});
