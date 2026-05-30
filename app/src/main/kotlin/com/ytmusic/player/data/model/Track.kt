package com.ytmusic.player.data.model

import android.os.Parcelable
import kotlinx.parcelize.Parcelize

@Parcelize
data class Track(
    val videoId: String,
    val title: String,
    val artists: List<String> = emptyList(),
    val album: Album? = null,
    val durationMs: Long = 0,
    val thumbnails: List<Thumbnail> = emptyList(),
    val isAvailable: Boolean = true,
    val isExplicit: Boolean = false,
    val setVideoId: String? = null,
    val lyricId: String? = null
) : Parcelable {
    val artist: String get() = artists.joinToString(", ")
    val albumArtUrl: String? get() = thumbnails.lastOrNull()?.url
    val durationFormatted: String
        get() {
            val totalSec = durationMs / 1000
            val min = totalSec / 60
            val sec = totalSec % 60
            return "%d:%02d".format(min, sec)
        }
}

@Parcelize
data class Album(
    val id: String? = null,
    val title: String? = null,
    val type: String? = null,
    val thumbnails: List<Thumbnail> = emptyList(),
    val year: Int? = null
) : Parcelable {
    val thumbnailUrl: String? get() = thumbnails.lastOrNull()?.url
}

@Parcelize
data class Thumbnail(
    val url: String,
    val width: Int = 0,
    val height: Int = 0
) : Parcelable

fun List<Thumbnail>.bestUrl(): String? = this.lastOrNull()?.url
