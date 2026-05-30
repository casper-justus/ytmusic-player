package com.ytmusic.player.auth

import android.webkit.CookieManager
import android.webkit.WebView
import android.webkit.WebViewClient
import android.webkit.WebSettings
import android.annotation.SuppressLint
import android.content.Context

object YTCookieManager {

    private const val YT_MUSIC_URL = "https://music.youtube.com"
    private const val SAPISID = "SAPISID"
    private const val SECURE_3PSAPISID = "__Secure-3PSAPISID"
    private const val LOGIN_COOKIE = "LOGIN_INFO"

    fun getCookies(url: String = YT_MUSIC_URL): String {
        return CookieManager.getInstance().getCookie(url) ?: ""
    }

    fun hasAuthCookies(): Boolean {
        val cookies = getCookies()
        return cookies.contains(SAPISID) || cookies.contains(SECURE_3PSAPISID)
    }

    fun hasLoginCookie(): Boolean {
        return getCookies().contains(LOGIN_COOKIE)
    }

    fun getSapisid(): String? {
        val cookies = getCookies()
        return cookies.split(";")
            .map { it.trim() }
            .firstOrNull { it.startsWith("$SAPISID=") || it.startsWith("$SECURE_3PSAPISID=") }
            ?.substringAfter("=")
    }

    fun clearCookies() {
        CookieManager.getInstance().removeAllCookies(null)
    }

    @SuppressLint("SetJavaScriptEnabled")
    fun createLoginWebView(context: Context, onPageLoaded: (WebView) -> Unit): WebView {
        return WebView(context).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.cacheMode = WebSettings.LOAD_DEFAULT
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
            settings.userAgentString = settings.userAgentString
                .replace("; wv", "")
                .replace("Version/\\d+\\..*? Chrome/", "Chrome/")

            CookieManager.getInstance().setAcceptCookie(true)
            CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)

            webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView, url: String) {
                    super.onPageFinished(view, url)
                    if (url.startsWith("https://music.youtube.com")) {
                        onPageLoaded(view)
                    }
                }
            }

            loadUrl("https://accounts.google.com/ServiceLogin?service=youtube&uilel=3&passive=true&continue=https://music.youtube.com&hl=en")
        }
    }
}
