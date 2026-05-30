package com.ytmusic.player

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentManager
import com.bumptech.glide.Glide
import com.google.android.material.bottomnavigation.BottomNavigationView
import com.ytmusic.player.audio.MusicService
import com.ytmusic.player.data.model.Track
import com.ytmusic.player.ui.fragments.HomeFragment
import com.ytmusic.player.ui.fragments.LibraryFragment
import com.ytmusic.player.ui.fragments.SearchFragment
import com.ytmusic.player.ui.player.PlayerActivity
import com.ytmusic.player.util.loadImage
import android.content.Intent
import android.content.ComponentName

class MainActivity : AppCompatActivity() {

    private lateinit var bottomNav: BottomNavigationView
    private lateinit var nowPlayingBar: LinearLayout
    private lateinit var npAlbumArt: ImageView
    private lateinit var npTitle: TextView
    private lateinit var npArtist: TextView
    private lateinit var npPlayPause: ImageButton
    private lateinit var npNext: ImageButton

    private val fragments = mutableMapOf<Int, Fragment>()
    private var currentFragment: Fragment? = null

    companion object {
        var currentTrack: Track? = null
            private set
        var isPlaying = false
            private set

        fun updateNowPlaying(track: Track?, playing: Boolean) {
            currentTrack = track
            isPlaying = playing
        }
    }

    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        bottomNav = findViewById(R.id.bottom_navigation)
        nowPlayingBar = findViewById(R.id.now_playing_bar)
        npAlbumArt = findViewById(R.id.np_album_art)
        npTitle = findViewById(R.id.np_title)
        npArtist = findViewById(R.id.np_artist)
        npPlayPause = findViewById(R.id.np_play_pause)
        npNext = findViewById(R.id.np_next)

        requestNotificationPermission()
        setupBottomNav()
        setupNowPlayingBar()
        showFragment(R.id.tab_home)
    }

    override fun onResume() {
        super.onResume()
        updateNowPlayingUI()
    }

    private fun setupBottomNav() {
        bottomNav.setOnItemSelectedListener { item ->
            showFragment(item.itemId)
            true
        }
        bottomNav.selectedItemId = R.id.tab_home
    }

    private fun showFragment(id: Int) {
        val fragment = fragments.getOrPut(id) {
            when (id) {
                R.id.tab_home -> HomeFragment()
                R.id.tab_search -> SearchFragment()
                R.id.tab_library -> LibraryFragment()
                else -> HomeFragment()
            }
        }

        supportFragmentManager.beginTransaction()
            .replace(R.id.fragment_container, fragment)
            .commit()
        currentFragment = fragment
    }

    private fun setupNowPlayingBar() {
        nowPlayingBar.setOnClickListener {
            startActivity(Intent(this, PlayerActivity::class.java))
        }

        npPlayPause.setOnClickListener {
            val intent = Intent(this, MusicService::class.java)
            if (isPlaying) {
                intent.action = "PAUSE"
            } else {
                intent.action = "PLAY"
            }
            startService(intent)
            updateNowPlayingUI()
        }

        npNext.setOnClickListener {
            val intent = Intent(this, MusicService::class.java).apply {
                action = "NEXT"
            }
            startService(intent)
        }
    }

    fun updateNowPlayingUI() {
        val track = currentTrack
        if (track != null) {
            nowPlayingBar.visibility = View.VISIBLE
            loadImage(track.albumArtUrl, npAlbumArt, R.drawable.ic_placeholder)
            npTitle.text = track.title
            npArtist.text = track.artist
            npPlayPause.setImageResource(
                if (isPlaying) R.drawable.ic_pause else R.drawable.ic_play
            )
        } else {
            nowPlayingBar.visibility = View.GONE
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this, Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                requestPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }
}
