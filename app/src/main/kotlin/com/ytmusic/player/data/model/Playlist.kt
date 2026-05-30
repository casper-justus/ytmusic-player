package com.ytmusic.player.data.model

import android.os.Parcelable
import kotlinx.parcelize.Parcelize

@Parcelize
data class Playlist(
    val id: String,
    val title: String,
    val description: String? = null,
    val trackCount: Int = 0,
    val durationMs: Long = 0,
    val thumbnails: List<Thumbnail> = emptyList(),
    val ownerName: String? = null,
    val tracks: List<Track> = emptyList()
) : Parcelable {
    val thumbnailUrl: String? get() = thumbnails.lastOrNull()?.url
}

@Parcelize
data class Section(
    val title: String,
    val items: List<SectionItem>,
    val browseId: String? = null
) : Parcelable

@Parcelize
data class SectionItem(
    val type: ItemType,
    val title: String,
    val subtitle: String? = null,
    val thumbnails: List<Thumbnail> = emptyList(),
    val videoId: String? = null,
    val browseId: String? = null,
    val playlistId: String? = null,
    val setVideoId: String? = null
) : Parcelable {
    val thumbnailUrl: String? get() = thumbnails.lastOrNull()?.url
}

enum class ItemType {
    SONG, ALBUM, PLAYLIST, ARTIST, VIDEO, MIX, UNKNOWN
}
