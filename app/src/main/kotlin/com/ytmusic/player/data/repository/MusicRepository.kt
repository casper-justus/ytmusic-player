package com.ytmusic.player.data.repository

import android.util.Log
import com.ytmusic.player.api.InnerTubeClient
import com.ytmusic.player.api.ResponseParser
import com.ytmusic.player.data.model.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class MusicRepository(
    private val client: InnerTubeClient = InnerTubeClient()
) {
    companion object {
        private const val TAG = "MusicRepository"
    }

    suspend fun getHomeSections(): Result<List<Section>> = withContext(Dispatchers.IO) {
        try {
            val result = client.browse("FEmusic_home")
            result.fold(
                onSuccess = { json ->
                    val sections = ResponseParser.parseHomeSections(json)
                    Result.success(sections)
                },
                onFailure = { Result.failure(it) }
            )
        } catch (e: Exception) {
            Log.e(TAG, "getHomeSections failed: ${e.message}", e)
            Result.failure(e)
        }
    }

    suspend fun getSearchResults(query: String): Result<List<SectionItem>> = withContext(Dispatchers.IO) {
        try {
            val result = client.search(query)
            result.fold(
                onSuccess = { json ->
                    val items = ResponseParser.parseSearchResults(json)
                    Result.success(items)
                },
                onFailure = { Result.failure(it) }
            )
        } catch (e: Exception) {
            Log.e(TAG, "search failed: ${e.message}", e)
            Result.failure(e)
        }
    }

    suspend fun getPlaylist(playlistId: String): Result<Pair<List<Track>, String?>> = withContext(Dispatchers.IO) {
        try {
            val result = client.getPlaylist(playlistId)
            result.fold(
                onSuccess = { json ->
                    val (tracks, name) = ResponseParser.parsePlaylistTracks(json)
                    Result.success(tracks to name)
                },
                onFailure = { Result.failure(it) }
            )
        } catch (e: Exception) {
            Log.e(TAG, "getPlaylist failed: ${e.message}", e)
            Result.failure(e)
        }
    }

    suspend fun getAlbum(browseId: String): Result<Pair<List<Track>, String?>> = withContext(Dispatchers.IO) {
        try {
            val result = client.getAlbum(browseId)
            result.fold(
                onSuccess = { json ->
                    val (tracks, name) = ResponseParser.parsePlaylistTracks(json)
                    Result.success(tracks to name)
                },
                onFailure = { Result.failure(it) }
            )
        } catch (e: Exception) {
            Log.e(TAG, "getAlbum failed: ${e.message}", e)
            Result.failure(e)
        }
    }

    suspend fun getUpNext(videoId: String, playlistId: String? = null): Result<List<Track>> = withContext(Dispatchers.IO) {
        try {
            val result = client.getNext(videoId, playlistId)
            result.fold(
                onSuccess = { json ->
                    val tracks = ResponseParser.parseUpNext(json)
                    Result.success(tracks)
                },
                onFailure = { Result.failure(it) }
            )
        } catch (e: Exception) {
            Log.e(TAG, "getUpNext failed: ${e.message}", e)
            Result.failure(e)
        }
    }

    suspend fun getLibraryPlaylists(): Result<List<SectionItem>> = withContext(Dispatchers.IO) {
        try {
            val result = client.getLibraryPlaylists()
            result.fold(
                onSuccess = { json ->
                    val items = ResponseParser.parseSearchResults(json)
                    Result.success(items)
                },
                onFailure = { Result.failure(it) }
            )
        } catch (e: Exception) {
            Log.e(TAG, "getLibraryPlaylists failed: ${e.message}", e)
            Result.failure(e)
        }
    }

    suspend fun getLikedSongs(): Result<Pair<List<Track>, String?>> = withContext(Dispatchers.IO) {
        try {
            val result = client.getLikedSongs()
            result.fold(
                onSuccess = { json ->
                    val (tracks, name) = ResponseParser.parsePlaylistTracks(json)
                    Result.success(tracks to name)
                },
                onFailure = { Result.failure(it) }
            )
        } catch (e: Exception) {
            Log.e(TAG, "getLikedSongs failed: ${e.message}", e)
            Result.failure(e)
        }
    }
}
