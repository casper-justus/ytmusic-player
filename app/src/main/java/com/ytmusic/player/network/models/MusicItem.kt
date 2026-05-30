package com.ytmusic.player.network.models

/**
 * Represents a music item from InnerTube API responses.
 * Can be a song, video, album, artist, or playlist.
 */
data class MusicItem(
    val type: ItemType,
    val title: String,
    val artist: String = "",
    val album: String = "",
    val thumbnailUrl: String = "",
    val videoId: String = "",
    val playlistId: String = "",
    val browseId: String = "",
    val duration: String = "",
    val year: String = "",
    val explicit: Boolean = false
)

enum class ItemType {
    SONG,
    VIDEO,
    ALBUM,
    ARTIST,
    PLAYLIST,
    STATION,
    UNKNOWN
}

/**
 * A section on the home screen (e.g., "Recommended", "Quick picks")
 */
data class MusicSection(
    val title: String,
    val items: List<MusicItem>
)

/**
 * Playlist detail
 */
data class Playlist(
    val id: String,
    val title: String,
    val description: String = "",
    val thumbnailUrl: String = "",
    val trackCount: Int = 0,
    val owner: String = "",
    val tracks: List<MusicItem> = emptyList()
)

/**
 * Artist info
 */
data class Artist(
    val id: String,
    val name: String,
    val thumbnailUrl: String = "",
    val subscribers: String = ""
)
