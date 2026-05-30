package com.ytmusic.player.ui.settings

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.ytmusic.player.R
import com.ytmusic.player.BuildConfig
import com.ytmusic.player.YTMusicApp
import com.ytmusic.player.auth.LoginActivity
import com.ytmusic.player.auth.YTCookieManager

class SettingsActivity : AppCompatActivity() {

    private lateinit var accountStatus: TextView
    private lateinit var loginButton: Button
    private lateinit var versionText: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)

        accountStatus = findViewById(R.id.settings_account_status)
        loginButton = findViewById(R.id.settings_login_button)
        versionText = findViewById(R.id.settings_version)

        versionText.text = "Version ${BuildConfig.VERSION_NAME}"

        updateAccountUI()

        loginButton.setOnClickListener {
            val prefs = YTMusicApp.instance.preferencesManager
            if (prefs.isLoggedIn) {
                AlertDialog.Builder(this)
                    .setTitle("Sign Out")
                    .setMessage("Are you sure you want to sign out?")
                    .setPositiveButton("Sign Out") { _, _ ->
                        prefs.clearAuth()
                        YTCookieManager.clearCookies()
                        updateAccountUI()
                        Toast.makeText(this, "Signed out", Toast.LENGTH_SHORT).show()
                    }
                    .setNegativeButton("Cancel", null)
                    .show()
            } else {
                startActivityForResult(
                    Intent(this, LoginActivity::class.java),
                    REQUEST_LOGIN
                )
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_LOGIN && resultCode == LoginActivity.RESULT_LOGIN_SUCCESS) {
            updateAccountUI()
            Toast.makeText(this, "Signed in successfully!", Toast.LENGTH_SHORT).show()
        }
    }

    private fun updateAccountUI() {
        val prefs = YTMusicApp.instance.preferencesManager
        if (prefs.isLoggedIn) {
            val name = prefs.displayName.ifEmpty { "Signed in" }
            accountStatus.text = name
            loginButton.text = "Sign Out"
        } else {
            accountStatus.text = "Not signed in"
            loginButton.text = "Sign In"
        }
    }

    override fun onDestroy() {
        super.onDestroy()
    }

    companion object {
        private const val REQUEST_LOGIN = 1001
    }
}
