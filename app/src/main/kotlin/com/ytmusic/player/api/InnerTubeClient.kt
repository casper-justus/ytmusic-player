package com.ytmusic.player.api

import android.util.Log
import com.google.gson.Gson
import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.ytmusic.player.auth.YTCookieManager
import com.ytmusic.player.data.model.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException

class InnerTubeClient {

    private val client = OkHttpClient.Builder()
        .followRedirects(true)
        .build()

    private val gson = Gson()

    companion object {
        private const val TAG = "InnerTube"
        private const val BASE_URL = "https://music.youtube.com/youtubei/v1"
        private const val API_KEY = "AIzaSyC9XL3ZjBddKy3g7NxLbYXQFMj8JN1UPPI"
        private const val CLIENT_NAME = "ANDROID_MUSIC"
        private const val CLIENT_VERSION = "7.02.51"

        private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()

    }

    private fun buildRequest(endpoint: String, body: JsonObject, cookies: String = ""): Request {
        val requestBody = body.toString().toRequestBody(JSON_MEDIA_TYPE)
        val url = "$BASE_URL/$endpoint?key=$API_KEY"

        return Request.Builder()
            .url(url)
            .post(requestBody)
            .header("Content-Type", "application/json")
            .header("User-Agent", "com.google.android.apps.youtube.music/7.02.51 (Linux; U; Android 14)")
            .header("Origin", "https://music.youtube.com")
            .apply {
                val c = cookies.ifEmpty { YTCookieManager.getCookies() }
                if (c.isNotBlank()) {
                    header("Cookie", c)
                }
                val sapisid = YTCookieManager.getSapisid()
                if (sapisid != null) {
                    val hash = "${System.currentTimeMillis()}_${sapisid}"
                    header("Authorization", "SAPISIDHASH $hash")
                }
            }
            .build()
    }

    private suspend fun executeRequest(request: Request): Result<JsonObject> = withContext(Dispatchers.IO) {
        try {
            val response = client.newCall(request).execute()
            val body = response.body?.string()
            if (!response.isSuccessful || body == null) {
                return@withContext Result.failure(IOException("HTTP ${response.code}: $body"))
            }
            val json = gson.fromJson(body, JsonObject::class.java)
            if (json.has("error")) {
                val err = json.getAsJsonObject("error")
                val msg = err?.get("message")?.asString ?: "Unknown error"
                return@withContext Result.failure(IOException("API error: $msg"))
            }
            Result.success(json)
        } catch (e: Exception) {
            Log.e(TAG, "Request failed: ${e.message}", e)
            Result.failure(e)
        }
    }

    private fun extractContext(): JsonObject {
        return JsonObject().apply {
            add("client", JsonObject().apply {
                addProperty("clientName", CLIENT_NAME)
                addProperty("clientVersion", CLIENT_VERSION)
                addProperty("osName", "Android")
                addProperty("osVersion", "14")
                addProperty("androidSdkVersion", 34)
                addProperty("platform", "MOBILE")
                addProperty("hl", "en")
                addProperty("gl", "US")
                add("musicAppInfo", JsonObject().apply {
                    addProperty("appVersion", CLIENT_VERSION)
                    addProperty("appName", "ytmusic")
                })
            })
            add("user", JsonObject().apply {
                addProperty("lockedSafetyMode", false)
            })
            add("request", JsonObject().apply {
                addProperty("useSsl", true)
            })
        }
    }

    // ========== Browse (Home / Sections) ==========

    suspend fun browse(browseId: String = "FEmusic_home"): Result<JsonObject> {
        val body = JsonObject().apply {
            add("context", extractContext())
            addProperty("browseId", browseId)
        }
        return executeRequest(buildRequest("browse", body))
    }

    // ========== Search ==========

    suspend fun search(query: String): Result<JsonObject> {
        val body = JsonObject().apply {
            add("context", extractContext())
            addProperty("query", query)
        }
        return executeRequest(buildRequest("search", body))
    }

    // ========== Get Playlist ==========

    suspend fun getPlaylist(playlistId: String): Result<JsonObject> {
        val body = JsonObject().apply {
            add("context", extractContext())
            addProperty("browseId", "VL$playlistId")
        }
        return executeRequest(buildRequest("browse", body))
    }

    // ========== Get Album / Artist ==========

    suspend fun getAlbum(browseId: String): Result<JsonObject> {
        return browse(browseId)
    }

    suspend fun getArtist(browseId: String): Result<JsonObject> {
        return browse(browseId)
    }

    // ========== Queue (next) ==========

    suspend fun getNext(videoId: String, playlistId: String? = null): Result<JsonObject> {
        val body = JsonObject().apply {
            add("context", extractContext())
            addProperty("videoId", videoId)
            if (playlistId != null) {
                addProperty("playlistId", playlistId)
            }
        }
        return executeRequest(buildRequest("next", body))
    }

    // ========== Library ==========

    suspend fun getLibraryPlaylists(): Result<JsonObject> {
        return browse("FEmusic_library_landing")
    }

    suspend fun getLikedSongs(): Result<JsonObject> {
        return browse("FEmusic_liked_videos")
    }
}
