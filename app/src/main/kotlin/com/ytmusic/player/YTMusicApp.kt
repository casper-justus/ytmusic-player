package com.ytmusic.player

import android.app.Application
import com.ytmusic.player.audio.MusicService
import com.ytmusic.player.data.local.PreferencesManager
import com.ytmusic.player.data.repository.MusicRepository
import com.ytmusic.player.download.DownloadManager

class YTMusicApp : Application() {

    lateinit var preferencesManager: PreferencesManager
        private set
    lateinit var musicRepository: MusicRepository
        private set
    lateinit var downloadManager: DownloadManager
        private set

    override fun onCreate() {
        super.onCreate()
        instance = this
        preferencesManager = PreferencesManager(this)
        musicRepository = MusicRepository()
        downloadManager = DownloadManager(this)
    }

    companion object {
        lateinit var instance: YTMusicApp
            private set
    }
}
