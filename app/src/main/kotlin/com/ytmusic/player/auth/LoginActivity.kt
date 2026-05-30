package com.ytmusic.player.auth

import android.content.Intent
import android.graphics.Bitmap
import android.os.Bundle
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.ProgressBar
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.ytmusic.player.R
import com.ytmusic.player.YTMusicApp
import com.ytmusic.player.data.local.PreferencesManager
import java.util.Timer
import kotlin.concurrent.timer

class LoginActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private lateinit var progressBar: ProgressBar
    private lateinit var prefs: PreferencesManager
    private var cookieCheckTimer: Timer? = null
    private var loginSuccess = false

    companion object {
        const val RESULT_LOGIN_SUCCESS = 100
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_login)

        prefs = (application as YTMusicApp).preferencesManager

        webView = findViewById(R.id.login_webview)
        progressBar = findViewById(R.id.login_progress)

        setupWebView()
        setupBackPress()
    }

    @Suppress("DEPRECATION")
    private fun setupWebView() {
        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.settings.cacheMode = android.webkit.WebSettings.LOAD_DEFAULT
        webView.settings.mixedContentMode = android.webkit.WebSettings.MIXED_CONTENT_ALWAYS_ALLOW

        android.webkit.CookieManager.getInstance().setAcceptCookie(true)
        android.webkit.CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true)

        webView.webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                progressBar.visibility = android.view.View.VISIBLE
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                progressBar.visibility = android.view.View.GONE
                if (url?.startsWith("https://music.youtube.com") == true) {
                    startCookiePolling()
                }
            }
        }

        webView.loadUrl("https://accounts.google.com/ServiceLogin?service=youtube&uilel=3&passive=true&continue=https://music.youtube.com&hl=en")
    }

    private fun startCookiePolling() {
        cookieCheckTimer?.cancel()
        cookieCheckTimer = timer("cookiePoll", false, 1000L, 1500L) {
            runOnUiThread {
                val cookies = YTCookieManager.getCookies()
                if (YTCookieManager.hasAuthCookies()) {
                    cookieCheckTimer?.cancel()
                    onLoginSuccess(cookies)
                }
            }
        }
    }

    private fun onLoginSuccess(cookies: String) {
        if (loginSuccess) return
        loginSuccess = true

        prefs.cookies = cookies
        prefs.isLoggedIn = true

        Toast.makeText(this, "Signed in successfully!", Toast.LENGTH_SHORT).show()

        setResult(RESULT_LOGIN_SUCCESS)
        finish()
    }

    private fun setupBackPress() {
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (webView.canGoBack()) {
                    webView.goBack()
                } else {
                    if (!loginSuccess) {
                        AlertDialog.Builder(this@LoginActivity)
                            .setTitle("Cancel sign in?")
                            .setMessage("You haven't completed signing in. Are you sure?")
                            .setPositiveButton("Yes") { _, _ -> finish() }
                            .setNegativeButton("No", null)
                            .show()
                    } else {
                        finish()
                    }
                }
            }
        })
    }

    override fun onDestroy() {
        super.onDestroy()
        cookieCheckTimer?.cancel()
    }
}
