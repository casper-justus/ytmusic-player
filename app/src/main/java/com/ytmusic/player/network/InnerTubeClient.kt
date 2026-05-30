package com.ytmusic.player.network

import android.util.Log
import com.google.gson.Gson
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.ytmusic.player.network.AuthManager.Companion.BASE_URL
import com.ytmusic.player.network.AuthManager.Companion.INNERTUBE_API_KEY
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

/**
 * Low-level InnerTube API client.
 * Handles POST requests to YouTube Music's InnerTube API endpoints.
 */
class InnerTubeClient(
    private val authManager: AuthManager
) {
    private val gson = Gson()
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    /**
     * Make a POST request to an InnerTube endpoint.
     *
     * @param endpoint e.g., "browse", "search", "next", "player"
     * @param body extra body fields merged with standard context
     * @return JSON response string
     */
    fun post(endpoint: String, body: Map<String, Any> = emptyMap()): String {
        val url = "$BASE_URL/$endpoint?key=$INNERTUBE_API_KEY"

        // Build full request payload with context
        val payload = mutableMapOf<String, Any>()
        payload.putAll(authManager.buildContext())
        payload.putAll(body)

        val jsonBody = gson.toJson(payload)
        val requestBody = jsonBody.toRequestBody(jsonMediaType)

        val requestBuilder = Request.Builder()
            .url(url)
            .post(requestBody)

        val headers = authManager.getHeaders()
        Log.d("YTM", "POST /$endpoint — cookies: ${headers["Cookie"]?.take(50) ?: "none"}..., auth: ${headers["Authorization"]?.take(30) ?: "none"}")
        headers.forEach { (key, value) ->
            requestBuilder.addHeader(key, value)
        }

        val response = client.newCall(requestBuilder.build()).execute()
        val responseBody = response.body?.string() ?: throw RuntimeException("Empty response")

        if (!response.isSuccessful) {
            Log.e("YTM", "API error ${response.code}: ${responseBody.take(500)}")
            throw RuntimeException("InnerTube API error ${response.code}: $responseBody")
        }

        // Log full response in chunks for debugging
        responseBody.chunked(3000).forEachIndexed { i, chunk ->
            Log.d("YTM", "Response[$i] /$endpoint: $chunk")
        }
        // Also dump to sdcard for analysis via `adb shell cat /sdcard/ytm_response.json`
        try {
            java.io.File("/sdcard/ytm_response_${endpoint.replace("/","_")}.json")
                .writeText(responseBody)
        } catch (_: Exception) { }
        return responseBody
    }

    /**
     * Parse a JSON string into a JsonObject
     */
    fun parseJson(json: String): JsonObject {
        return JsonParser.parseString(json).asJsonObject
    }
}
