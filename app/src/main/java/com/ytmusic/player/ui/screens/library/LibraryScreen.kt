package com.ytmusic.player.ui.screens.library

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.ytmusic.player.network.AuthManager
import com.ytmusic.player.network.InnerTubeClient
import com.ytmusic.player.network.InnerTubeParser
import com.ytmusic.player.network.models.MusicItem
import com.ytmusic.player.ui.theme.*
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryScreen(
    authManager: AuthManager,
    onNavigateToPlayer: () -> Unit
) {
    val client = remember { InnerTubeClient(authManager) }
    var playlists by remember { mutableStateOf<List<MusicItem>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var selectedTab by remember { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        scope.launch {
            try {
                val json = client.post("browse", mapOf(
                    "browseId" to "FEmusic_library_landing"
                ))
                playlists = InnerTubeParser.parseLibraryPlaylists(client.parseJson(json))
            } catch (_: Exception) {}
            isLoading = false
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Library", fontWeight = FontWeight.Bold, color = OnDark) },
                navigationIcon = {
                    IconButton(onClick = { /* back handled by nav */ }) {
                        Icon(Icons.Default.ArrowBack, "Back", tint = OnDark)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background)
            )
        }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            // Tab row
            TabRow(
                selectedTabIndex = selectedTab,
                containerColor = MaterialTheme.colorScheme.background,
                contentColor = PrimaryRed
            ) {
                Tab(selected = selectedTab == 0, onClick = { selectedTab = 0 }, text = { Text("Playlists") })
                Tab(selected = selectedTab == 1, onClick = { selectedTab = 1 }, text = { Text("Downloads") })
            }

            when {
                isLoading -> {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = PrimaryRed)
                    }
                }
                selectedTab == 0 -> {
                    if (playlists.isEmpty()) {
                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Text("No playlists found", color = OnDarkMuted)
                        }
                    } else {
                        LazyColumn(contentPadding = PaddingValues(8.dp)) {
                            items(playlists) { playlist ->
                                PlaylistItem(playlist = playlist, onClick = onNavigateToPlayer)
                            }
                        }
                    }
                }
                selectedTab == 1 -> {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("Downloads coming soon", color = OnDarkMuted)
                    }
                }
            }
        }
    }
}

@Composable
fun PlaylistItem(playlist: MusicItem, onClick: () -> Unit) {
    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = MaterialTheme.shapes.small
    ) {
        Row(modifier = Modifier.padding(8.dp)) {
            AsyncImage(
                model = playlist.thumbnailUrl,
                contentDescription = playlist.title,
                modifier = Modifier.size(64.dp)
            )
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f).align(Alignment.CenterVertically)) {
                Text(playlist.title, color = OnDark, fontWeight = FontWeight.Medium)
            }
        }
    }
}
