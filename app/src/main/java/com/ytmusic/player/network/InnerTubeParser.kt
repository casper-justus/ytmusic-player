package com.ytmusic.player.network

import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.ytmusic.player.network.models.ItemType
import com.ytmusic.player.network.models.MusicItem
import com.ytmusic.player.network.models.MusicSection

/**
 * Parses InnerTube API JSON responses into typed model objects.
 *
 * InnerTube uses deeply nested structures with renderer objects.
 * This parser extracts music items from the various renderer types.
 */
object InnerTubeParser {

    /**
     * Parse home screen browse response into sections.
     */
    fun parseHomeSections(json: JsonObject): List<MusicSection> {
        val sections = mutableListOf<MusicSection>()

        try {
            val contents = json
                .getAsJsonObject("contents")
                ?.getAsJsonObject("singleColumnBrowseResultsRenderer")
                ?.getAsJsonArray("tabs")
                ?.get(0)?.asJsonObject
                ?.getAsJsonObject("tabRenderer")
                ?.getAsJsonObject("content")
                ?.getAsJsonObject("sectionListRenderer")
                ?.getAsJsonArray("contents") ?: return sections

            for (sectionElement in contents) {
                val section = parseSection(sectionElement.asJsonObject) ?: continue
                sections.add(section)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return sections
    }

    /**
     * Parse a single section from the home page.
     */
    private fun parseSection(obj: JsonObject): MusicSection? {
        try {
            val musicCarousel = obj.getAsJsonObject("musicCarouselShelfRenderer") ?: return null
            val header = musicCarousel.getAsJsonObject("header")
                ?.getAsJsonObject("musicCarouselShelfBasicHeaderRenderer")
                ?.getAsJsonObject("title")
                ?.getAsJsonArray("runs")
                ?.get(0)?.asJsonObject
                ?.get("text")?.asString ?: ""

            val contents = musicCarousel.getAsJsonArray("contents") ?: return null
            val items = mutableListOf<MusicItem>()

            for (content in contents) {
                val item = parseMusicItem(content.asJsonObject) ?: continue
                items.add(item)
            }

            return MusicSection(title = header, items = items)
        } catch (e: Exception) {
            return null
        }
    }

    /**
     * Parse a single music item from a content element.
     * InnerTube uses various renderer types.
     */
    fun parseMusicItem(obj: JsonObject): MusicItem? {
        try {
            // Try musicResponsiveListItemRenderer (most common)
            val renderer = obj.getAsJsonObject("musicResponsiveListItemRenderer") ?: return null

            val flexColumns = renderer.getAsJsonArray("flexColumns") ?: return null

            // Extract title from first flex column
            val title = extractText(flexColumns[0]?.asJsonObject) ?: return null

            // Extract subtitle/artist from second flex column
            val subtitle = if (flexColumns.size() > 1) {
                extractText(flexColumns[1]?.asJsonObject) ?: ""
            } else ""

            // Extract thumbnail
            val thumbnail = extractThumbnail(renderer)

            // Extract navigation data
            val navEndpoint = renderer
                .getAsJsonObject("navigationEndpoint")
            val navResult = extractNavigation(navEndpoint)
            val videoId = navResult.first
            val browseId = navResult.second
            val playlistId = navResult.third
            val itemType = determineItemType(renderer, browseId)

            return MusicItem(
                type = itemType,
                title = title,
                artist = subtitle,
                thumbnailUrl = thumbnail,
                videoId = videoId,
                browseId = browseId,
                playlistId = playlistId
            )
        } catch (e: Exception) {
            return null
        }
    }

    /**
     * Parse search results
     */
    fun parseSearchResults(json: JsonObject): List<MusicItem> {
        val items = mutableListOf<MusicItem>()

        try {
            val contents = json
                .getAsJsonObject("contents")
                ?.getAsJsonObject("tabRenderer")
                ?.getAsJsonObject("content")
                ?.getAsJsonObject("sectionListRenderer")
                ?.getAsJsonArray("contents") ?: return items

            for (section in contents) {
                val itemSection = section.asJsonObject
                    .getAsJsonObject("musicShelfRenderer")
                    ?.getAsJsonArray("contents") ?: continue

                for (content in itemSection) {
                    val item = parseMusicItem(content.asJsonObject) ?: continue
                    items.add(item)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return items
    }

    /**
     * Parse library playlists
     */
    fun parseLibraryPlaylists(json: JsonObject): List<MusicItem> {
        val items = mutableListOf<MusicItem>()

        try {
            val contents = json
                .getAsJsonObject("contents")
                ?.getAsJsonObject("singleColumnBrowseResultsRenderer")
                ?.getAsJsonArray("tabs")
                ?.get(0)?.asJsonObject
                ?.getAsJsonObject("tabRenderer")
                ?.getAsJsonObject("content")
                ?.getAsJsonObject("sectionListRenderer")
                ?.getAsJsonArray("contents") ?: return items

            for (section in contents) {
                val gridRenderer = section.asJsonObject
                    .getAsJsonObject("gridRenderer")
                    ?.getAsJsonArray("items") ?: continue

                for (content in gridRenderer) {
                    val renderer = content.asJsonObject.getAsJsonObject("musicTwoRowItemRenderer") ?: continue
                    val title = renderer
                        .getAsJsonObject("title")
                        ?.getAsJsonArray("runs")
                        ?.get(0)?.asJsonObject
                        ?.get("text")?.asString ?: continue

                    val thumbnail = extractThumbnailFromRenderer(renderer)
                    val navEndpoint = renderer.getAsJsonObject("navigationEndpoint")
                    val (_, browseId, _) = extractNavigation(navEndpoint)

                    items.add(MusicItem(
                        type = ItemType.PLAYLIST,
                        title = title,
                        thumbnailUrl = thumbnail,
                        browseId = browseId ?: ""
                    ))
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return items
    }

    // ---- Helper methods ----

    private fun extractText(column: JsonObject?): String? {
        if (column == null) return null
        try {
            val runs = column
                .getAsJsonObject("musicResponsiveListItemFlexColumnRenderer")
                ?.getAsJsonObject("text")
                ?.getAsJsonArray("runs") ?: return null
            return runs.map { it.asJsonObject.get("text")?.asString ?: "" }.joinToString("")
        } catch (e: Exception) {
            return null
        }
    }

    private fun extractThumbnail(renderer: JsonObject): String {
        try {
            val thumbnails = renderer
                .getAsJsonObject("thumbnail")
                ?.getAsJsonObject("musicThumbnailRenderer")
                ?.getAsJsonObject("thumbnail")
                ?.getAsJsonArray("thumbnails")
            return thumbnails?.last()?.asJsonObject?.get("url")?.asString ?: ""
        } catch (e: Exception) {
            return ""
        }
    }

    private fun extractThumbnailFromRenderer(renderer: JsonObject): String {
        try {
            val thumbnails = renderer
                .getAsJsonObject("thumbnailRenderer")
                ?.getAsJsonObject("musicThumbnailRenderer")
                ?.getAsJsonObject("thumbnail")
                ?.getAsJsonArray("thumbnails")
            return thumbnails?.last()?.asJsonObject?.get("url")?.asString ?: ""
        } catch (e: Exception) {
            return ""
        }
    }

    private fun extractNavigation(endpoint: JsonObject?): Triple<String, String, String> {
        if (endpoint == null) return Triple("", "", "")

        val watchEndpoint = endpoint.getAsJsonObject("watchEndpoint")
        if (watchEndpoint != null) {
            val videoId = watchEndpoint.get("videoId")?.asString
            val playlistId = watchEndpoint.get("playlistId")?.asString
            return Triple(videoId ?: "", "", playlistId ?: "")
        }

        val browseEndpoint = endpoint.getAsJsonObject("browseEndpoint")
        if (browseEndpoint != null) {
            val browseId = browseEndpoint.get("browseId")?.asString
            return Triple("", browseId ?: "", "")
        }

        return Triple("", "", "")
    }

    private fun determineItemType(renderer: JsonObject, browseId: String?): ItemType {
        if (browseId != null) {
            return when {
                browseId.startsWith("VL") || browseId.startsWith("RD") -> ItemType.PLAYLIST
                browseId.startsWith("UC") -> ItemType.ARTIST
                browseId.startsWith("MP") -> ItemType.ALBUM
                else -> ItemType.UNKNOWN
            }
        }

        // Check for badges or overlay to determine type
        val badges = renderer.getAsJsonArray("badges")
        if (badges != null && badges.size() > 0) {
            return ItemType.SONG
        }

        return ItemType.SONG
    }
}
