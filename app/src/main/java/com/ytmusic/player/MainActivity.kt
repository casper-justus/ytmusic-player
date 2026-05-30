package com.ytmusic.player

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.ytmusic.player.network.AuthManager
import com.ytmusic.player.ui.screens.home.HomeScreen
import com.ytmusic.player.ui.screens.library.LibraryScreen
import com.ytmusic.player.ui.screens.player.PlayerScreen
import com.ytmusic.player.ui.screens.search.SearchScreen
import com.ytmusic.player.ui.theme.YTMusicTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        setContent {
            YTMusicTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    MainNavigation()
                }
            }
        }
    }
}

@Composable
fun MainNavigation() {
    val navController = rememberNavController()
    val authManager = remember { AuthManager() }
    var isLoggedIn by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        isLoggedIn = authManager.isLoggedIn()
    }

    // If not logged in, show auth screen first
    if (!isLoggedIn) {
        AuthScreen(
            authManager = authManager,
            onLoggedIn = { isLoggedIn = true }
        )
        return
    }

    NavHost(
        navController = navController,
        startDestination = "home"
    ) {
        composable("home") {
            HomeScreen(
                authManager = authManager,
                onNavigateToPlayer = { navController.navigate("player") },
                onNavigateToSearch = { navController.navigate("search") },
                onNavigateToLibrary = { navController.navigate("library") }
            )
        }
        composable("search") {
            SearchScreen(
                authManager = authManager,
                onNavigateToPlayer = { navController.navigate("player") },
                onBack = { navController.popBackStack() }
            )
        }
        composable("library") {
            LibraryScreen(
                authManager = authManager,
                onNavigateToPlayer = { navController.navigate("player") }
            )
        }
        composable("player") {
            PlayerScreen(
                onBack = { navController.popBackStack() }
            )
        }
    }
}
