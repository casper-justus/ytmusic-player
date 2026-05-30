package com.ytmusic.player.ui.screens.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LibraryMusic
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.ytmusic.player.network.AuthManager
import com.ytmusic.player.network.InnerTubeClient
import com.ytmusic.player.network.InnerTubeParser
import com.ytmusic.player.network.models.MusicItem
import com.ytmusic.player.network.models.MusicSection
import com.ytmusic.player.ui.theme.OnDark
import com.ytmusic.player.ui.theme.OnDarkMuted
import com.ytmusic.player.ui.theme.OnDarkSecondary
import com.ytmusic.player.ui.theme.PrimaryRed
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    authManager: AuthManager,
    onNavigateToPlayer: () -> Unit,
    onNavigateToSearch: () -> Unit,
    onNavigateToLibrary: () -> Unit
) {
    val client = remember { InnerTubeClient(authManager) }
    var sections by remember { mutableStateOf<List<MusicSection>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        scope.launch {
            try {
                val json = client.post("browse", mapOf(
                    "browseId" to "FEmusic_home"
                ))
                val parsed = InnerTubeParser.parseHomeSections(client.parseJson(json))
                sections = parsed
                isLoading = false
            } catch (e: Exception) {
                error = e.message
                isLoading = false
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text("YTMusic", fontWeight = FontWeight.Bold, color = OnDark)
                },
                actions = {
                    IconButton(onClick = onNavigateToSearch) {
                        Icon(Icons.Default.Search, "Search", tint = OnDark)
                    }
                    IconButton(onClick = onNavigateToLibrary) {
                        Icon(Icons.Default.LibraryMusic, "Library", tint = OnDark)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        }
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when {
                isLoading -> {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = PrimaryRed)
                    }
                }
                error != null -> {
                    Column(modifier = Modifier.fillMaxSize().padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("Something went wrong", color = OnDark, style = MaterialTheme.typography.titleMedium)
                        Spacer(Modifier.height(8.dp))
                        Text(error ?: "", color = OnDarkSecondary, style = MaterialTheme.typography.bodySmall)
                        Spacer(Modifier.height(16.dp))
                        Button(onClick = {
                            isLoading = true; error = null
                            scope.launch { /* re-fetch */ }
                        }) {
                            Text("Retry")
                        }
                    }
                }
                sections.isEmpty() -> {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("No recommendations yet", color = OnDarkMuted)
                    }
                }
                else -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(bottom = 80.dp)
                    ) {
                        sections.forEach { section ->
                            item {
                                Text(
                                    section.title,
                                    color = OnDark,
                                    fontSize = 20.sp,
                                    fontWeight = FontWeight.Bold,
                                    modifier = Modifier.padding(start = 16.dp, top = 16.dp, bottom = 8.dp)
                                )
                            }
                            item {
                                LazyRow(
                                    contentPadding = PaddingValues(horizontal = 8.dp)
                                ) {
                                    items(section.items) { item ->
                                        MusicCard(item = item, onClick = {
                                            // TODO: Navigate to player with this track
                                            onNavigateToPlayer()
                                        })
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun MusicCard(item: MusicItem, onClick: () -> Unit) {
    Card(
        onClick = onClick,
        modifier = Modifier
            .width(160.dp)
            .padding(8.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = MaterialTheme.shapes.medium
    ) {
        Column {
            AsyncImage(
                model = item.thumbnailUrl,
                contentDescription = item.title,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp)
            )
            Column(modifier = Modifier.padding(8.dp)) {
                Text(
                    item.title,
                    color = OnDark,
                    fontSize = 14.sp,
                    maxLines = 2,
                    fontWeight = FontWeight.Medium
                )
                if (item.artist.isNotBlank()) {
                    Text(
                        item.artist,
                        color = OnDarkSecondary,
                        fontSize = 12.sp,
                        maxLines = 1
                    )
                }
            }
        }
    }
}
