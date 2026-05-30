package com.ytmusic.player.ui.screens.search

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
fun SearchScreen(
    authManager: AuthManager,
    onNavigateToPlayer: () -> Unit,
    onBack: () -> Unit
) {
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<MusicItem>>(emptyList()) }
    var isLoading by remember { mutableStateOf(false) }
    val client = remember { InnerTubeClient(authManager) }
    val scope = rememberCoroutineScope()

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    TextField(
                        value = query,
                        onValueChange = { query = it },
                        placeholder = { Text("Search songs, artists...", color = OnDarkMuted) },
                        colors = TextFieldDefaults.colors(
                            focusedContainerColor = MaterialTheme.colorScheme.surface,
                            unfocusedContainerColor = MaterialTheme.colorScheme.surface,
                            focusedIndicatorColor = PrimaryRed,
                            unfocusedIndicatorColor = OnDarkMuted,
                            focusedTextColor = OnDark,
                            unfocusedTextColor = OnDark
                        ),
                        singleLine = true
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, "Back", tint = OnDark)
                    }
                },
                actions = {
                    TextButton(onClick = {
                        if (query.isBlank()) return@TextButton
                        isLoading = true
                        scope.launch {
                            try {
                                val json = client.post("search", mapOf(
                                    "query" to query
                                ))
                                results = InnerTubeParser.parseSearchResults(client.parseJson(json))
                            } catch (_: Exception) {}
                            isLoading = false
                        }
                    }) {
                        Text("Search", color = PrimaryRed)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background)
            )
        }
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            if (isLoading) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = PrimaryRed)
            } else if (results.isEmpty() && query.isNotBlank()) {
                Text("No results", color = OnDarkMuted, modifier = Modifier.align(Alignment.Center))
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(8.dp)
                ) {
                    items(results) { item ->
                        SearchResultItem(item = item, onClick = onNavigateToPlayer)
                    }
                }
            }
        }
    }
}

@Composable
fun SearchResultItem(item: MusicItem, onClick: () -> Unit) {
    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = MaterialTheme.shapes.small
    ) {
        Row(modifier = Modifier.padding(8.dp)) {
            AsyncImage(
                model = item.thumbnailUrl,
                contentDescription = item.title,
                modifier = Modifier.size(56.dp)
            )
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f).align(Alignment.CenterVertically)) {
                Text(item.title, color = OnDark, style = MaterialTheme.typography.bodyLarge)
                if (item.artist.isNotBlank()) {
                    Text(item.artist, color = OnDarkSecondary, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}
