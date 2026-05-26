import 'track.dart';

/// Represents a playlist from YouTube Music or user-created.
class PlaylistItem {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final List<Track> tracks;
  final int trackCount;
  final String? owner;
  final bool isEditable;

  const PlaylistItem({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.tracks = const [],
    this.trackCount = 0,
    this.owner,
    this.isEditable = false,
  });

  PlaylistItem copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    List<Track>? tracks,
    int? trackCount,
    String? owner,
    bool? isEditable,
  }) {
    return PlaylistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      tracks: tracks ?? this.tracks,
      trackCount: trackCount ?? this.trackCount,
      owner: owner ?? this.owner,
      isEditable: isEditable ?? this.isEditable,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'tracks': tracks.map((t) => t.toJson()).toList(),
        'trackCount': trackCount,
        'owner': owner,
        'isEditable': isEditable,
      };

  factory PlaylistItem.fromJson(Map<String, dynamic> json) => PlaylistItem(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
        tracks: (json['tracks'] as List<dynamic>?)
                ?.map((t) => Track.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
        trackCount: json['trackCount'] as int? ?? 0,
        owner: json['owner'] as String?,
        isEditable: json['isEditable'] as bool? ?? false,
      );
}
