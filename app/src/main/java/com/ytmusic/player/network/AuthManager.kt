package com.ytmusic.player.network

import android.content.Context
import android.content.SharedPreferences
import android.webkit.CookieManager
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.ytmusic.player.YTMusicApp
import java.security.MessageDigest

/**
 * Manages YouTube Music authentication via cookies and SAPISIDHASH.
 *
 * The InnerTube API requires:
 * 1. Session cookies (e.g., __Secure-3PSAPISID, SAPISID, __Secure-3PAPISID)
 * 2. An Authorization header: SAPISIDHASH <timestamp>_<SHA1(timestamp + " " + SAPISID + " " + origin)>
 */
class AuthManager {

    private val prefs: SharedPreferences by lazy {
        val context = YTMusicApp.instance
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            "auth_prefs",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    companion object {
        const val INNERTUBE_API_KEY = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
        const val BASE_URL = "https://music.youtube.com/youtubei/v1"
        const val ORIGIN = "https://music.youtube.com"

        // Client context for InnerTube requests
        // WEB_REMIX (desktop web) returns old renderer format (musicCarouselShelfRenderer etc.)
        // ANDROID_MUSIC has migrated to the new Element rendering system (elementRenderer).
        val CLIENT_CONTEXT = mapOf(
            "client" to mapOf(
                "clientName" to "WEB_REMIX",
                "clientVersion" to "1.20250122.01.00",
                "platform" to "DESKTOP",
                "gl" to "US",
                "hl" to "en"
            )
        )
    }

    /** Check if we have stored cookies */
    fun isLoggedIn(): Boolean {
        val cookies = getCookies()
        return cookies.contains("SAPISID") || cookies.contains("__Secure-3PSAPISID")
    }

    /** Save cookies after WebView login */
    fun saveCookies(cookies: String) {
        prefs.edit().putString("yt_cookies", cookies).apply()
    }

    /** Get stored cookies */
    fun getCookies(): String {
        return prefs.getString("yt_cookies", "") ?: ""
    }

    /** Clear cookies (logout) */
    fun clearCookies() {
        prefs.edit().remove("yt_cookies").apply()
        CookieManager.getInstance().removeAllCookies(null)
    }

    /**
     * Generate the SAPISIDHASH Authorization header.
     *
     * Formula: SHA1(timestamp + " " + SAPISID + " " + ORIGIN)
     * Then: SAPISIDHASH <timestamp>_<hash>
     */
    fun generateSapisidHash(): String? {
        val cookies = getCookies()
        // Try multiple cookie names for SAPISID
        val sapisid = extractCookie(cookies, "__Secure-3PSAPISID")
            ?: extractCookie(cookies, "SAPISID")
            ?: return null

        val timestamp = System.currentTimeMillis() / 1000
        val hashInput = "$timestamp $sapisid $ORIGIN"
        val hash = sha1(hashInput)
        return "SAPISIDHASH ${timestamp}_$hash"
    }

    /** Extract a single cookie value by name */
    private fun extractCookie(cookieHeader: String, name: String): String? {
        // Handle both "name=value;" and "name=value" formats
        val regex = Regex("(?:^|;\\s*)$name=([^;]+)")
        return regex.find(cookieHeader)?.groupValues?.get(1)
    }

    /** SHA-1 hash */
    private fun sha1(input: String): String {
        val digest = MessageDigest.getInstance("SHA-1")
        val bytes = digest.digest(input.toByteArray())
        return bytes.joinToString("") { java.lang.String.format("%02x", it) }
    }

    /** Build standard InnerTube headers */
    fun getHeaders(): Map<String, String> {
        val headers = mutableMapOf(
            "Content-Type" to "application/json",
            "X-YouTube-Client-Name" to "1",  // WEB_REMIX
            "X-YouTube-Client-Version" to "1.20250122.01.00",
            "Origin" to ORIGIN,
            "User-Agent" to "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )

        val cookies = getCookies()
        if (cookies.isNotBlank()) {
            headers["Cookie"] = cookies
        }

        val auth = generateSapisidHash()
        if (auth != null) {
            headers["Authorization"] = auth
        }

        return headers
    }

    /** Build the standard request body context */
    fun buildContext(): Map<String, Any> {
        return mapOf("context" to CLIENT_CONTEXT)
    }
}
