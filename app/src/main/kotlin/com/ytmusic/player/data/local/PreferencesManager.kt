package com.ytmusic.player.data.local

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class PreferencesManager(context: Context) {

    private val prefs: SharedPreferences by lazy {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            "ytmusic_prefs",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    var cookies: String
        get() = prefs.getString(KEY_COOKIES, "") ?: ""
        set(value) = prefs.edit().putString(KEY_COOKIES, value).apply()

    var isLoggedIn: Boolean
        get() = prefs.getBoolean(KEY_LOGGED_IN, false)
        set(value) = prefs.edit().putBoolean(KEY_LOGGED_IN, value).apply()

    var displayName: String
        get() = prefs.getString(KEY_DISPLAY_NAME, "") ?: ""
        set(value) = prefs.edit().putString(KEY_DISPLAY_NAME, value).apply()

    var audioQuality: String
        get() = prefs.getString(KEY_AUDIO_QUALITY, "AUTO") ?: "AUTO"
        set(value) = prefs.edit().putString(KEY_AUDIO_QUALITY, value).apply()

    var downloadLocation: String
        get() = prefs.getString(KEY_DOWNLOAD_LOCATION, "") ?: ""
        set(value) = prefs.edit().putString(KEY_DOWNLOAD_LOCATION, value).apply()

    fun clearAuth() {
        prefs.edit()
            .putString(KEY_COOKIES, "")
            .putBoolean(KEY_LOGGED_IN, false)
            .putString(KEY_DISPLAY_NAME, "")
            .apply()
    }

    companion object {
        private const val KEY_COOKIES = "cookies"
        private const val KEY_LOGGED_IN = "logged_in"
        private const val KEY_DISPLAY_NAME = "display_name"
        private const val KEY_AUDIO_QUALITY = "audio_quality"
        private const val KEY_DOWNLOAD_LOCATION = "download_location"
    }
}
