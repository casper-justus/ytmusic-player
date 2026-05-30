package com.ytmusic.player.ui.player

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.SeekBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.bumptech.glide.Glide
import com.ytmusic.player.R
import com.ytmusic.player.audio.MusicService
import com.ytmusic.player.data.model.Track
import com.ytmusic.player.util.loadImage
import com.ytmusic.player.util.ImageUtils
import com.ytmusic.player.util.getDominantColor
import kotlinx.coroutines.*

class PlayerActivity : AppCompatActivity() {

    private lateinit var albumArt: ImageView
    private lateinit var titleText: TextView
    private lateinit var artistText: TextView
    private lateinit var currentTimeText: TextView
    private lateinit var totalTimeText: TextView
    private lateinit var seekBar: SeekBar
    private lateinit var playPauseBtn: ImageButton
    private lateinit var nextBtn: ImageButton
    private lateinit var prevBtn: ImageButton
    private lateinit var queueRecycler: RecyclerView
    private lateinit var backgroundGradient: View
    private lateinit var shuffleBtn: ImageButton
    private lateinit var repeatBtn: ImageButton

    private val handler = Handler(Looper.getMainLooper())
    private val updateProgress = object : Runnable {
        override fun run() {
            updateProgressUI()
            handler.postDelayed(this, 500)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_player)

        albumArt = findViewById(R.id.player_album_art)
        titleText = findViewById(R.id.player_title)
        artistText = findViewById(R.id.player_artist)
        currentTimeText = findViewById(R.id.player_current_time)
        totalTimeText = findViewById(R.id.player_total_time)
        seekBar = findViewById(R.id.player_seekbar)
        playPauseBtn = findViewById(R.id.player_play_pause)
        nextBtn = findViewById(R.id.player_next)
        prevBtn = findViewById(R.id.player_prev)
        queueRecycler = findViewById(R.id.player_queue)
        backgroundGradient = findViewById(R.id.player_background)
        shuffleBtn = findViewById(R.id.player_shuffle)
        repeatBtn = findViewById(R.id.player_repeat)

        setupControls()
        setupQueue()
        updateUI()
    }

    override fun onStart() {
        super.onStart()
        handler.post(updateProgress)
    }

    override fun onStop() {
        super.onStop()
        handler.removeCallbacks(updateProgress)
    }

    private fun setupControls() {
        playPauseBtn.setOnClickListener {
            val intent = android.content.Intent(this, MusicService::class.java).apply {
                action = "TOGGLE_PLAYPAUSE"
            }
            ContextCompat.startForegroundService(this, intent)
            updateUI()
        }

        nextBtn.setOnClickListener {
            val intent = android.content.Intent(this, MusicService::class.java).apply { action = "NEXT" }
            ContextCompat.startForegroundService(this, intent)
        }

        prevBtn.setOnClickListener {
            val intent = android.content.Intent(this, MusicService::class.java).apply { action = "PREV" }
            ContextCompat.startForegroundService(this, intent)
        }

        seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {}
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {
                val intent = android.content.Intent(this@PlayerActivity, MusicService::class.java).apply {
                    action = "SEEK"
                    putExtra("position", seekBar?.progress?.toLong() ?: 0L)
                }
                ContextCompat.startForegroundService(this@PlayerActivity, intent)
            }
        })

        shuffleBtn.setOnClickListener {
            val intent = android.content.Intent(this, MusicService::class.java).apply { action = "SHUFFLE" }
            ContextCompat.startForegroundService(this, intent)
        }

        repeatBtn.setOnClickListener {
            val intent = android.content.Intent(this, MusicService::class.java).apply { action = "REPEAT" }
            ContextCompat.startForegroundService(this, intent)
        }

        findViewById<ImageButton>(R.id.player_back).setOnClickListener { finish() }
        findViewById<ImageButton>(R.id.player_cast).setOnClickListener {
            showCastDialog()
        }
    }

    private fun setupQueue() {
        queueRecycler.layoutManager = LinearLayoutManager(this)
    }

    private fun updateUI() {
        val track = MusicService.getCurrentTrack()
        if (track != null) {
            titleText.text = track.title
            artistText.text = track.artist
            loadImage(track.albumArtUrl, albumArt, R.drawable.ic_placeholder)

            // Load dominant color for background
            if (track.albumArtUrl != null) {
                CoroutineScope(Dispatchers.IO).launch {
                    val bitmap = ImageUtils.loadBitmap(this@PlayerActivity, track.albumArtUrl!!)
                    if (bitmap != null) {
                        val color = getDominantColor(bitmap)
                        withContext(Dispatchers.Main) {
                            val gradient = GradientDrawable(
                                GradientDrawable.Orientation.TOP_BOTTOM,
                                intArrayOf(color, Color.BLACK)
                            )
                            backgroundGradient.background = gradient
                        }
                    }
                }
            }

            playPauseBtn.setImageResource(
                if (MusicService.isPlaying()) R.drawable.ic_pause
                else R.drawable.ic_play
            )
        }
    }

    private fun updateProgressUI() {
        // Progress would update from MusicService
    }

    private fun showCastDialog() {
        // TODO: Implement cast dialog
    }
}
