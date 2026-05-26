import 'track.dart';

/// Represents an album from YouTube Music.
class Album {
  final String id;
  final String name;
  final String artist;
  final String? artistId;
  final int? year;
  final String? imageUrl;
  final List<Track> tracks;
  final int trackCount;
  final String? description;

  const Album({
    required this.id,
    required this.name,
    required this.artist,
    this.artistId,
    this.year,
    this.imageUrl,
    this.tracks = const [],
    this.trackCount = 0,
    this.description,
  });

  Album copyWith({
    String? id,
    String? name,
    String? artist,
    String? artistId,
    int? year,
    String? imageUrl,
    List<Track>? tracks,
    int? trackCount,
    String? description,
  }) {
    return Album(
      id: id ?? this.id,
      name: name ?? this.name,
      artist: artist ?? this.artist,
      artistId: artistId ?? this.artistId,
      year: year ?? this.year,
      imageUrl: imageUrl ?? this.imageUrl,
      tracks: tracks ?? this.tracks,
      trackCount: trackCount ?? this.trackCount,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'artist': artist,
        'artistId': artistId,
        'year': year,
        'imageUrl': imageUrl,
        'tracks': tracks.map((t) => t.toJson()).toList(),
        'trackCount': trackCount,
        'description': description,
      };

  factory Album.fromJson(Map<String, dynamic> json) => Album(
        id: json['id'] as String,
        name: json['name'] as String,
        artist: json['artist'] as String,
        artistId: json['artistId'] as String?,
        year: json['year'] as int?,
        imageUrl: json['imageUrl'] as String?,
        tracks: (json['tracks'] as List<dynamic>?)
                ?.map((t) => Track.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
        trackCount: json['trackCount'] as int? ?? 0,
        description: json['description'] as String?,
      );
}
