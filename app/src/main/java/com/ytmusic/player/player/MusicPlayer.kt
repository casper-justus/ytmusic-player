package com.ytmusic.player.player

import android.content.Context
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import com.ytmusic.player.network.models.MusicItem
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Wrapper around ExoPlayer for music playback.
 *
 * Handles:
 * - Play/pause/seek
 * - Queue management
 * - Stream URL resolution via InnerTube
 */
class MusicPlayer(context: Context) {

    private val exoPlayer: ExoPlayer = ExoPlayer.Builder(context).build()

    private val _currentTrack = MutableStateFlow<MusicItem?>(null)
    val currentTrack: StateFlow<MusicItem?> = _currentTrack.asStateFlow()

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _progress = MutableStateFlow(0L)
    val progress: StateFlow<Long> = _progress.asStateFlow()

    private val _duration = MutableStateFlow(0L)
    val duration: StateFlow<Long> = _duration.asStateFlow()

    private val queue = mutableListOf<MusicItem>()
    private var currentIndex = -1

    init {
        exoPlayer.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                when (state) {
                    Player.STATE_READY -> {
                        _duration.value = exoPlayer.duration.coerceAtLeast(0)
                    }
                    Player.STATE_ENDED -> {
                        playNext()
                    }
                }
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                _isPlaying.value = isPlaying
            }
        })
    }

    /** Play a single track */
    fun play(track: MusicItem, streamUrl: String) {
        val mediaItem = MediaItem.Builder()
            .setMediaId(track.videoId)
            .setUri(streamUrl)
            .build()

        exoPlayer.setMediaItem(mediaItem)
        exoPlayer.prepare()
        exoPlayer.play()

        _currentTrack.value = track
        currentIndex = 0
        queue.clear()
        queue.add(track)
    }

    /** Play a list of tracks starting from given index */
    fun playQueue(tracks: List<MusicItem>, startIndex: Int = 0) {
        // TODO: Build playlist from multiple MediaItems
        currentIndex = startIndex
        queue.clear()
        queue.addAll(tracks)

        // For now, just play the first one
        if (tracks.isNotEmpty()) {
            val track = tracks[startIndex]
            // Stream URL needs to be resolved separately through InnerTube
            _currentTrack.value = track
        }
    }

    fun playNext() {
        if (currentIndex < queue.size - 1) {
            currentIndex++
            // Would need to resolve stream URL for the next track
            _currentTrack.value = queue[currentIndex]
        } else {
            pause()
        }
    }

    fun playPrevious() {
        if (currentIndex > 0) {
            currentIndex--
            _currentTrack.value = queue[currentIndex]
        }
    }

    fun togglePlayPause() {
        if (exoPlayer.isPlaying) {
            exoPlayer.pause()
        } else {
            exoPlayer.play()
        }
    }

    fun pause() {
        exoPlayer.pause()
    }

    fun resume() {
        exoPlayer.play()
    }

    fun seekTo(position: Long) {
        exoPlayer.seekTo(position)
    }

    fun release() {
        exoPlayer.release()
    }
}
