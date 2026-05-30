package com.ytmusic.player

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class YTMusicApp : Application() {

    override fun onCreate() {
        super.onCreate()
        instance = this

        // Create notification channel for playback
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            MUSIC_CHANNEL_ID,
            "Music Playback",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Shows currently playing track"
            setShowBadge(false)
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val MUSIC_CHANNEL_ID = "com.ytmusic.player.music_channel"

        lateinit var instance: YTMusicApp
            private set
    }
}
