package com.ytmusic.player

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.view.ViewGroup
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.ytmusic.player.network.AuthManager
import com.ytmusic.player.ui.theme.*

/**
 * Login screen that loads YouTube Music in a WebView.
 * After the user signs in, cookies are captured for API access.
 */
@SuppressLint("SetJavaScriptEnabled")
@Composable
fun AuthScreen(
    authManager: AuthManager,
    onLoggedIn: () -> Unit
) {
    var showWebView by remember { mutableStateOf(false) }
    var cookies by remember { mutableStateOf("") }

    if (!showWebView) {
        // Welcome / Login button
        Box(
            modifier = Modifier.fillMaxSize().padding(32.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    "YTMusic",
                    fontSize = 36.sp,
                    fontWeight = FontWeight.Bold,
                    color = PrimaryRed
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    "A YouTube Music player",
                    color = OnDarkSecondary,
                    fontSize = 14.sp
                )
                Spacer(Modifier.height(48.dp))
                Button(
                    onClick = { showWebView = true },
                    colors = ButtonDefaults.buttonColors(containerColor = PrimaryRed)
                ) {
                    Text("Sign in with Google", fontSize = 16.sp)
                }
            }
        }
    } else {
        // WebView for login
        AndroidView(
            factory = { context ->
                WebView(context).apply {
                    layoutParams = ViewGroup.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT
                    )
                    settings.javaScriptEnabled = true
                    settings.domStorageEnabled = true

                    webViewClient = object : WebViewClient() {
                        override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                            super.onPageStarted(view, url, favicon)
                            // Capture cookies whenever a page loads
                            android.webkit.CookieManager.getInstance().let { cm ->
                                val allCookies = cm.getCookie("https://music.youtube.com")
                                    ?: cm.getCookie("https://www.youtube.com") ?: ""
                                if (allCookies.isNotBlank()) {
                                    cookies = allCookies
                                }
                            }
                        }

                        override fun onPageFinished(view: WebView?, url: String?) {
                            super.onPageFinished(view, url)
                            // After login, check if we have SAPISID cookies
                            if (cookies.contains("SAPISID") || cookies.contains("__Secure-3PSAPISID")) {
                                authManager.saveCookies(cookies)
                                // Also inject cookies for youtube.com
                                android.webkit.CookieManager.getInstance().let { cm ->
                                    val ytCookies = cm.getCookie("https://www.youtube.com") ?: ""
                                    if (ytCookies.isNotBlank()) {
                                        authManager.saveCookies(cookies + "; " + ytCookies)
                                    }
                                }
                                onLoggedIn()
                            }
                        }
                    }

                    // Also capture on page finished with a cookie sync
                    loadUrl("https://music.youtube.com")
                }
            },
            modifier = Modifier.fillMaxSize()
        )
    }
}
