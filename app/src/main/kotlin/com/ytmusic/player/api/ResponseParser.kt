package com.ytmusic.player.api

import android.util.Log
import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.ytmusic.player.data.model.*

object ResponseParser {

    private const val TAG = "ResponseParser"

    // ========== Home Sections ==========

    fun parseHomeSections(json: JsonObject): List<Section> {
        val sections = mutableListOf<Section>()

        try {
            val contents = json
                .getAsJsonObject("contents")
                ?.getAsJsonObject("singleColumnBrowseResultsRenderer")
                ?.getAsJsonArray("tabs")
                ?.firstOrNull()?.asJsonObject
                ?.getAsJsonObject("tabRenderer")
                ?.getAsJsonObject("content")
                ?.getAsJsonObject("sectionListRenderer")
                ?.getAsJsonArray("contents")

            if (contents == null) {
                Log.w(TAG, "No sectionList contents found")
                return sections
            }

            for (item in contents) {
                val section = parseSection(item)
                if (section != null) sections.add(section)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing home sections: ${e.message}", e)
        }

        return sections
    }

    private fun parseSection(json: JsonElement): Section? {
        return try {
            val renderer = json.asJsonObject?.getAsJsonObject("musicCarouselShelfRenderer")
                ?: json.asJsonObject?.getAsJsonObject("musicDescriptionShelfRenderer")
                ?: return null

            val title = renderer
                .getAsJsonObject("header")
                ?.getAsJsonObject("musicCarouselShelfBasicHeaderRenderer")
                ?.getAsJsonObject("title")
                ?.getAsJsonArray("runs")
                ?.firstOrNull()?.asJsonObject
                ?.get("text")?.asString
                ?: "Unknown"

            val items = mutableListOf<SectionItem>()
            val contents = renderer.getAsJsonArray("contents")

            contents?.forEach { content ->
                val item = parseSectionItem(content)
                if (item != null) items.add(item)
            }

            Section(title = title, items = items)
        } catch (e: Exception) {
            Log.w(TAG, "Error parsing section: ${e.message}")
            null
        }
    }

    private fun parseSectionItem(json: JsonElement): SectionItem? {
        return try {
            val obj = json.asJsonObject

            // MusicResponsiveListItemRenderer
            val respRenderer = obj.getAsJsonObject("musicResponsiveListItemRenderer")
            if (respRenderer != null) {
                return parseResponsiveListItem(respRenderer)
            }

            // MusicTwoRowItemRenderer
            val twoRow = obj.getAsJsonObject("musicTwoRowItemRenderer")
            if (twoRow != null) {
                return parseTwoRowItem(twoRow)
            }

            // MusicNavigationButtonRenderer
            val navBtn = obj.getAsJsonObject("musicNavigationButtonRenderer")
            if (navBtn != null) {
                return parseNavButton(navBtn)
            }

            null
        } catch (e: Exception) {
            Log.w(TAG, "Error parsing section item: ${e.message}")
            null
        }
    }

    private fun parseResponsiveListItem(renderer: JsonObject): SectionItem {
        val title = renderer
            .getAsJsonArray("flexColumns")
            ?.firstOrNull()?.asJsonObject
            ?.getAsJsonObject("musicResponsiveListItemFlexColumnRenderer")
            ?.getAsJsonObject("text")
            ?.getAsJsonArray("runs")
            ?.firstOrNull()?.asJsonObject
            ?.get("text")?.asString
            ?: "Unknown"

        val subtitle = renderer
            .getAsJsonArray("flexColumns")
            ?.getOrNull(1)?.asJsonObject
            ?.getAsJsonObject("musicResponsiveListItemFlexColumnRenderer")
            ?.getAsJsonObject("text")
            ?.getAsJsonArray("runs")
            ?.joinToString("") { it.asJsonObject.get("text")?.asString ?: "" }

        val thumbnails = parseThumbnails(renderer)
        val videoId = renderer
            .getAsJsonArray("playlistItemData")
            ?.firstOrNull()?.asJsonObject
            ?.get("videoId")?.asString
            ?: renderer.getAsJsonObject("overlay")
                ?.getAsJsonObject("musicItemThumbnailOverlayRenderer")
                ?.getAsJsonObject("content")
                ?.getAsJsonObject("musicPlayButtonRenderer")
                ?.getAsJsonObject("playNavigationEndpoint")
                ?.get("watchEndpointVideoId")?.asString

        val browseId = renderer
            .getAsJsonObject("navigationEndpoint")
            ?.get("browseEndpointBrowseId")?.asString

        val playlistId = renderer
            .getAsJsonObject("overlay")
            ?.getAsJsonObject("musicItemThumbnailOverlayRenderer")
            ?.getAsJsonObject("content")
            ?.getAsJsonObject("musicPlayButtonRenderer")
            ?.getAsJsonObject("playNavigationEndpoint")
            ?.get("watchEndpointPlaylistId")?.asString

        val setVideoId = renderer
            .getAsJsonObject("overlay")
            ?.getAsJsonObject("musicItemThumbnailOverlayRenderer")
            ?.getAsJsonObject("content")
            ?.getAsJsonObject("musicPlayButtonRenderer")
            ?.getAsJsonObject("playNavigationEndpoint")
            ?.get("watchEndpointSetVideoId")?.asString

        val itemType = when {
            browseId?.startsWith("MPRE") == true -> ItemType.ALBUM
            browseId?.startsWith("UC") == true -> ItemType.ARTIST
            browseId?.startsWith("VLPL") == true -> ItemType.PLAYLIST
            browseId?.startsWith("PL") == true -> ItemType.PLAYLIST
            videoId != null -> ItemType.SONG
            else -> ItemType.UNKNOWN
        }

        return SectionItem(
            type = itemType,
            title = title,
            subtitle = subtitle?.takeIf { it.isNotBlank() },
            thumbnails = thumbnails,
            videoId = videoId,
            browseId = browseId,
            playlistId = playlistId,
            setVideoId = setVideoId
        )
    }

    private fun parseTwoRowItem(renderer: JsonObject): SectionItem {
        val title = renderer
            .getAsJsonObject("title")
            ?.getAsJsonArray("runs")
            ?.firstOrNull()?.asJsonObject
            ?.get("text")?.asString
            ?: "Unknown"

        val subtitle = renderer
            .getAsJsonObject("subtitle")
            ?.getAsJsonArray("runs")
            ?.joinToString("") { it.asJsonObject.get("text")?.asString ?: "" }

        val thumbnails = parseThumbnails(renderer)
        val browseId = renderer
            .getAsJsonObject("navigationEndpoint")
            ?.get("browseEndpointBrowseId")?.asString

        val videoId = renderer
            .getAsJsonObject("navigationEndpoint")
            ?.getAsJsonObject("watchEndpoint")
            ?.get("videoId")?.asString

        val playlistId = renderer
            .getAsJsonObject("navigationEndpoint")
            ?.getAsJsonObject("watchEndpoint")
            ?.get("playlistId")?.asString

        return SectionItem(
            type = when {
                browseId?.startsWith("MPRE") == true -> ItemType.ALBUM
                browseId?.startsWith("UC") == true -> ItemType.ARTIST
                browseId?.startsWith("FEmusic") == true -> ItemType.MIX
                videoId != null -> ItemType.SONG
                else -> ItemType.UNKNOWN
            },
            title = title,
            subtitle = subtitle?.takeIf { it.isNotBlank() },
            thumbnails = thumbnails,
            videoId = videoId,
            browseId = browseId,
            playlistId = playlistId
        )
    }

    private fun parseNavButton(renderer: JsonObject): SectionItem {
        val title = renderer
            .getAsJsonObject("text")
            ?.getAsJsonArray("runs")
            ?.firstOrNull()?.asJsonObject
            ?.get("text")?.asString
            ?: "See all"

        val browseId = renderer
            .getAsJsonObject("navigationEndpoint")
            ?.get("browseEndpointBrowseId")?.asString

        return SectionItem(
            type = ItemType.UNKNOWN,
            title = title,
            browseId = browseId
        )
    }

    // ========== Search Results ==========

    fun parseSearchResults(json: JsonObject): List<SectionItem> {
        val items = mutableListOf<SectionItem>()

        try {
            val contents = json
                .getAsJsonObject("contents")
                ?.getAsJsonObject("tabRenderer")
                ?.getAsJsonObject("content")
                ?.getAsJsonObject("sectionListRenderer")
                ?.getAsJsonArray("contents")

            // Also try top-level tabbed search results
            val tabs = json
                .getAsJsonObject("contents")
                ?.getAsJsonArray("tabs")
                ?.firstOrNull()?.asJsonObject
                ?.getAsJsonObject("tabRenderer")
                ?.getAsJsonObject("content")
                ?.getAsJsonObject("sectionListRenderer")
                ?.getAsJsonArray("contents")

            val sections = contents ?: tabs ?: return items

            for (section in sections) {
                val musicShelf = section.asJsonObject
                    .getAsJsonObject("musicShelfRenderer")
                    ?: continue

                val shelfContents = musicShelf.getAsJsonArray("contents")
                shelfContents?.forEach { content ->
                    val item = parseSectionItem(content)
                    if (item != null) items.add(item)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing search results: ${e.message}", e)
        }

        return items
    }

    // ========== Playlist Tracks ==========

    fun parsePlaylistTracks(json: JsonObject): Pair<List<Track>, String?> {
        val tracks = mutableListOf<Track>()
        var playlistName: String? = null

        try {
            val header = json
                .getAsJsonObject("contents")
                ?.getAsJsonObject("singleColumnBrowseResultsRenderer")
                ?.getAsJsonArray("tabs")
                ?.firstOrNull()?.asJsonObject
                ?.getAsJsonObject("tabRenderer")
                ?.getAsJsonObject("content")
                ?.getAsJsonObject("sectionListRenderer")
                ?.getAsJsonArray("contents")
                ?.firstOrNull()?.asJsonObject
                ?.getAsJsonObject("musicPlaylistShelfRenderer")

            if (header == null) return tracks to null

            playlistName = try {
                json.getAsJsonObject("header")
                    ?.getAsJsonObject("musicDetailHeaderRenderer")
                    ?.getAsJsonObject("title")
                    ?.getAsJsonArray("runs")
                    ?.firstOrNull()?.asJsonObject
                    ?.get("text")?.asString
                    ?: json.getAsJsonObject("header")
                        ?.getAsJsonObject("musicResponsiveHeaderRenderer")
                        ?.getAsJsonObject("title")
                        ?.getAsJsonArray("runs")
                        ?.firstOrNull()?.asJsonObject
                        ?.get("text")?.asString
            } catch (_: Exception) { null }

            val contents = header.getAsJsonArray("contents")
            contents?.forEach { content ->
                val track = parseTrackFromResponsiveItem(content)
                if (track != null) tracks.add(track)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing playlist tracks: ${e.message}", e)
        }

        return tracks to playlistName
    }

    // ========== Track Parsing ==========

    fun parseTrackFromResponsiveItem(json: JsonElement): Track? {
        return try {
            val renderer = json.asJsonObject
                .getAsJsonObject("musicResponsiveListItemRenderer")
                ?: return null

            val titleFlex = renderer
                .getAsJsonArray("flexColumns")
                ?.firstOrNull()?.asJsonObject
                ?.getAsJsonObject("musicResponsiveListItemFlexColumnRenderer")

            val title = titleFlex
                ?.getAsJsonObject("text")
                ?.getAsJsonArray("runs")
                ?.firstOrNull()?.asJsonObject
                ?.get("text")?.asString
                ?: "Unknown"

            val artists = mutableListOf<String>()
            val subtitleRuns = renderer
                .getAsJsonArray("flexColumns")
                ?.getOrNull(1)?.asJsonObject
                ?.getAsJsonObject("musicResponsiveListItemFlexColumnRenderer")
                ?.getAsJsonObject("text")
                ?.getAsJsonArray("runs")

            subtitleRuns?.forEach { run ->
                val text = run.asJsonObject.get("text")?.asString ?: return@forEach
                val nav = run.asJsonObject.getAsJsonObject("navigationEndpoint")
                if (nav?.get("browseEndpointBrowseId")?.asString?.startsWith("UC") == true ||
                    (artists.isEmpty() && text !in arrayOf("•", ",", " "))
                ) {
                    artists.add(text)
                }
            }

            val thumbnails = parseThumbnails(renderer)
            val videoId = renderer
                .getAsJsonArray("playlistItemData")
                ?.firstOrNull()?.asJsonObject
                ?.get("videoId")?.asString
                ?: renderer
                    .getAsJsonObject("overlay")
                    ?.getAsJsonObject("musicItemThumbnailOverlayRenderer")
                    ?.getAsJsonObject("content")
                    ?.getAsJsonObject("musicPlayButtonRenderer")
                    ?.getAsJsonObject("playNavigationEndpoint")
                    ?.get("watchEndpointVideoId")?.asString

            if (videoId == null) return null

            val durationMs = parseDurationMs(
                renderer
                    .getAsJsonArray("flexColumns")
                    ?.getOrNull(2)?.asJsonObject
                    ?.getAsJsonObject("musicResponsiveListItemFlexColumnRenderer")
                    ?.getAsJsonObject("text")
                    ?.getAsJsonArray("runs")
                    ?.firstOrNull()?.asJsonObject
                    ?.get("text")?.asString
            )

            val setVideoId = renderer
                .getAsJsonObject("overlay")
                ?.getAsJsonObject("musicItemThumbnailOverlayRenderer")
                ?.getAsJsonObject("content")
                ?.getAsJsonObject("musicPlayButtonRenderer")
                ?.getAsJsonObject("playNavigationEndpoint")
                ?.get("watchEndpointSetVideoId")?.asString

            Track(
                videoId = videoId,
                title = title,
                artists = artists,
                durationMs = durationMs,
                thumbnails = thumbnails,
                setVideoId = setVideoId
            )
        } catch (e: Exception) {
            Log.w(TAG, "Error parsing track item: ${e.message}")
            null
        }
    }

    // ========== Queue (Up Next) ==========

    fun parseUpNext(json: JsonObject): List<Track> {
        val tracks = mutableListOf<Track>()

        try {
            val contents = json
                .getAsJsonObject("contents")
                ?.getAsJsonObject("singleColumnMusicWatchNextResultsRenderer")
                ?.getAsJsonObject("tabbedRenderer")
                ?.getAsJsonObject("watchNextTabbedResultsRenderer")

            val playback = contents
                ?.getAsJsonArray("tabs")
                ?.firstOrNull()?.asJsonObject
                ?.getAsJsonObject("tabRenderer")
                ?.getAsJsonObject("content")
                ?.getAsJsonObject("musicQueueRenderer")
                ?.getAsJsonObject("content")
                ?.getAsJsonObject("playlistPanelRenderer")
                ?.getAsJsonArray("contents")

            playback?.forEach { content ->
                val renderer = content.asJsonObject
                    .getAsJsonObject("playlistPanelVideoRenderer")
                    ?: content.asJsonObject
                        .getAsJsonObject("playlistPanelVideoWrapperRenderer")
                        ?.getAsJsonObject("primaryRenderer")
                        ?.getAsJsonObject("playlistPanelVideoRenderer")
                    ?: return@forEach

                val videoId = renderer.get("videoId")?.asString ?: return@forEach
                val title = renderer
                    .getAsJsonObject("title")
                    ?.getAsJsonArray("runs")
                    ?.firstOrNull()?.asJsonObject
                    ?.get("text")?.asString
                    ?: "Unknown"

                val artists = mutableListOf<String>()
                val longSubtitle = renderer.getAsJsonObject("longBylineText")
                longSubtitle?.getAsJsonArray("runs")?.forEach { run ->
                    val text = run.asJsonObject.get("text")?.asString ?: return@forEach
                    if (text !in arrayOf("•", ",", " ")) artists.add(text)
                }

                val thumbnails = renderer
                    .getAsJsonObject("thumbnail")
                    ?.getAsJsonArray("thumbnails")
                    ?.map { Thumbnail(it.asJsonObject.get("url")?.asString ?: "", it.asJsonObject.get("width")?.asInt ?: 0, it.asJsonObject.get("height")?.asInt ?: 0) }
                    ?: emptyList()

                val durationMs = parseDurationMs(
                    renderer.getAsJsonArray("lengthText")
                        ?.getAsJsonObject("runs")
                        ?.firstOrNull()?.asJsonObject
                        ?.get("text")?.asString
                )

                tracks.add(Track(
                    videoId = videoId,
                    title = title,
                    artists = artists,
                    durationMs = durationMs,
                    thumbnails = thumbnails
                ))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing up next: ${e.message}", e)
        }

        return tracks
    }

    // ========== Helpers ==========

    private fun parseThumbnails(obj: JsonObject): List<Thumbnail> {
        val thumbnails = mutableListOf<Thumbnail>()
        try {
            val thumbnailRenderer = obj.getAsJsonObject("thumbnail")
                ?: return thumbnails

            val overlayed = thumbnailRenderer.getAsJsonObject("musicThumbnailRenderer")
                ?.getAsJsonObject("thumbnail")
                ?: thumbnailRenderer

            val list = overlayed.getAsJsonArray("thumbnails")
            list?.forEach { t ->
                val url = t.asJsonObject.get("url")?.asString
                if (url != null) {
                    thumbnails.add(Thumbnail(
                        url = url,
                        width = t.asJsonObject.get("width")?.asInt ?: 0,
                        height = t.asJsonObject.get("height")?.asInt ?: 0
                    ))
                }
            }
        } catch (_: Exception) {}
        return thumbnails
    }

    private fun parseDurationMs(text: String?): Long {
        if (text.isNullOrBlank()) return 0L
        try {
            val parts = text.split(":")
            return when (parts.size) {
                2 -> parts[0].toLongOrNull()?.let { it * 60 * 1000 + (parts[1].toLongOrNull() ?: 0) * 1000 } ?: 0L
                3 -> parts[0].toLongOrNull()?.let { it * 3600 * 1000 + (parts[1].toLongOrNull() ?: 0) * 60 * 1000 + (parts[2].toLongOrNull() ?: 0) * 1000 } ?: 0L
                else -> text.toLongOrNull() ?: 0L
            }
        } catch (_: Exception) { return 0L }
    }
}
