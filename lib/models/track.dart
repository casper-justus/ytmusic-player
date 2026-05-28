/// Represents a single audio track from YouTube Music.
class Track {
  final String id;
  final String videoId;
  final String title;
  final String artist;
  final String? album;
  final String? albumArtUrl;
  final Duration duration;
  final String? streamUrl;
  final bool isDownloaded;
  final String? localPath;
  final String? contentUri;
  final String? artistId;
  final String? albumId;

  const Track({
    required this.id,
    required this.videoId,
    required this.title,
    required this.artist,
    this.album,
    this.albumArtUrl,
    this.duration = Duration.zero,
    this.streamUrl,
    this.isDownloaded = false,
    this.localPath,
    this.contentUri,
    this.artistId,
    this.albumId,
  });

  Track copyWith({
    String? id,
    String? videoId,
    String? title,
    String? artist,
    String? album,
    String? albumArtUrl,
    Duration? duration,
    String? streamUrl,
    bool? isDownloaded,
    String? localPath,
    String? contentUri,
    String? artistId,
    String? albumId,
  }) {
    return Track(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtUrl: albumArtUrl ?? this.albumArtUrl,
      duration: duration ?? this.duration,
      streamUrl: streamUrl ?? this.streamUrl,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localPath: localPath ?? this.localPath,
      contentUri: contentUri ?? this.contentUri,
      artistId: artistId ?? this.artistId,
      albumId: albumId ?? this.albumId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'videoId': videoId,
        'title': title,
        'artist': artist,
        'album': album,
        'albumArtUrl': albumArtUrl,
        'duration': duration.inMilliseconds,
        'streamUrl': streamUrl,
        'isDownloaded': isDownloaded,
        'localPath': localPath,
        'contentUri': contentUri,
        'artistId': artistId,
        'albumId': albumId,
      };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String,
        videoId: json['videoId'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        album: json['album'] as String?,
        albumArtUrl: json['albumArtUrl'] as String?,
        duration: Duration(milliseconds: json['duration'] as int? ?? 0),
        streamUrl: json['streamUrl'] as String?,
        isDownloaded: json['isDownloaded'] as bool? ?? false,
        localPath: json['localPath'] as String?,
        contentUri: json['contentUri'] as String?,
        artistId: json['artistId'] as String?,
        albumId: json['albumId'] as String?,
      );

  @override
  String toString() => 'Track($title - $artist)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Track && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
