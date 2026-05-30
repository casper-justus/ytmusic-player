package com.ytmusic.player.audio

import android.app.PendingIntent
import android.content.Intent
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.ytmusic.player.data.model.Track
import com.ytmusic.player.ui.player.PlayerActivity

class MusicService : MediaSessionService() {

    private lateinit var player: ExoPlayer
    private lateinit var mediaSession: MediaSession
    private val notificationManager by lazy { MusicNotificationManager(this) }

    companion object {
        private var currentTrack: Track? = null
        private var _isPlaying = false

        fun getCurrentTrack(): Track? = currentTrack
        fun isPlaying(): Boolean = _isPlaying
    }

    override fun onCreate() {
        super.onCreate()

        player = ExoPlayer.Builder(this)
            .setAudioAttributes(AudioAttributes.DEFAULT, true)
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .build()

        player.addListener(object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                _isPlaying = isPlaying
                if (isPlaying) {
                    notificationManager.startNotification(
                        this@MusicService,
                        mediaSession.sessionCompatToken
                    )
                } else {
                    notificationManager.stopNotification()
                }
            }

            override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
                updateMetadataFromMediaItem(mediaItem)
            }
        })

        mediaSession = MediaSession.Builder(this, player)
            .setSessionActivity(createPlayerPendingIntent())
            .build()

        notificationManager.createChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action?.uppercase()) {
            "PLAY" -> { player.play() }
            "PAUSE" -> { player.pause() }
            "TOGGLE_PLAYPAUSE", "PLAY_PAUSE" -> togglePlayPause()
            "NEXT" -> skipToNext()
            "PREV", "PREVIOUS" -> skipToPrevious()
            "SEEK" -> {
                val pos = intent.getLongExtra("position", player.currentPosition)
                seekTo(pos)
            }
            "STOP" -> {
                player.stop()
                stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (!player.playWhenReady) {
            stopSelf()
        }
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = mediaSession

    override fun onDestroy() {
        notificationManager.stopNotification()
        mediaSession.run {
            player.stop()
            release()
        }
        player.release()
        super.onDestroy()
    }

    fun playTrack(track: Track, tracks: List<Track> = listOf(track)) {
        currentTrack = track

        val mediaItems = tracks.map { t ->
            val streamUrl = t.albumArtUrl ?: ""
            MediaItem.Builder()
                .setMediaId(t.videoId)
                .setUri(streamUrl)
                .setTag(t)
                .build()
        }

        player.setMediaItems(mediaItems)
        player.prepare()
        player.playWhenReady = true
    }

    fun togglePlayPause() {
        if (player.isPlaying) {
            player.pause()
        } else {
            player.play()
        }
    }

    fun skipToNext() {
        player.seekToNextMediaItem()
    }

    fun skipToPrevious() {
        player.seekToPreviousMediaItem()
    }

    fun seekTo(positionMs: Long) {
        player.seekTo(positionMs)
    }

    fun getPlayerPosition(): Long = player.currentPosition
    fun getPlayerDuration(): Long = player.duration
    fun getQueue(): MutableList<MediaItem> = player.mediaItems

    private fun updateMetadataFromMediaItem(mediaItem: MediaItem?) {
        val track = mediaItem?.localConfiguration?.tag as? Track ?: return
        currentTrack = track
    }

    private fun createPlayerPendingIntent(): PendingIntent {
        val intent = Intent(this, PlayerActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
