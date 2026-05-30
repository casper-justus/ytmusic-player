package com.ytmusic.player.download

import android.content.Context
import android.os.Environment
import android.util.Log
import com.ytmusic.player.data.model.Track
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONArray
import org.json.JSONObject

class DownloadManager(private val context: Context) {

    companion object {
        private const val TAG = "DownloadManager"
        private const val DOWNLOADS_DIR = "YTMusic"
    }

    data class DownloadInfo(
        val track: Track,
        val localPath: String?,
        val isDownloaded: Boolean
    )

    private val downloadsDir: File
        get() {
            val dir = File(
                context.getExternalFilesDir(Environment.DIRECTORY_MUSIC),
                DOWNLOADS_DIR
            )
            if (!dir.exists()) dir.mkdirs()
            return dir
        }

    private val metadataFile: File
        get() = File(context.filesDir, "downloads.json")

    fun getDownloadedTracks(): List<DownloadInfo> {
        val metadata = loadMetadata()
        return metadata.map { entry ->
            val path = entry.optString("path", null)
            DownloadInfo(
                track = Track(
                    videoId = entry.getString("videoId"),
                    title = entry.getString("title"),
                    artists = listOf(entry.optString("artist", "Unknown")),
                    thumbnails = listOf(
                        com.ytmusic.player.data.model.Thumbnail(
                            url = entry.optString("albumArtUrl", "")
                        )
                    )
                ),
                localPath = path,
                isDownloaded = path != null && File(path).exists()
            )
        }
    }

    fun isDownloaded(track: Track): Boolean {
        return getDownloadedTracks().any { it.track.videoId == track.videoId && it.isDownloaded }
    }

    suspend fun downloadTrack(track: Track, onProgress: (Float) -> Unit): Result<String> {
        return withContext(Dispatchers.IO) {
            try {
                val fileName = "${track.videoId}.m4a"
                val outputFile = File(downloadsDir, fileName)

                // Get audio stream URL from InnerTube or use placeholder
                val streamUrl = resolveStreamUrl(track)

                val url = URL(streamUrl)
                val connection = url.openConnection() as HttpURLConnection
                connection.connect()

                val totalSize = connection.contentLengthLong
                val inputStream = connection.inputStream
                val outputStream = FileOutputStream(outputFile)

                val buffer = ByteArray(8192)
                var bytesRead: Int
                var totalBytes = 0L

                while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                    outputStream.write(buffer, 0, bytesRead)
                    totalBytes += bytesRead
                    if (totalSize > 0) {
                        onProgress(totalBytes.toFloat() / totalSize)
                    }
                }

                outputStream.close()
                inputStream.close()
                connection.disconnect()

                saveMetadata(track, outputFile.absolutePath)
                Result.success(outputFile.absolutePath)
            } catch (e: Exception) {
                Log.e(TAG, "Download failed: ${e.message}", e)
                Result.failure(e)
            }
        }
    }

    fun deleteDownload(track: Track) {
        val metadataList = loadMetadataMutable()
        val entry = metadataList.find { it.optString("videoId") == track.videoId }
        val path = entry?.optString("path")
        if (path != null) {
            File(path).delete()
        }
        metadataList.removeAll { it.optString("videoId") == track.videoId }
        saveMetadataList(metadataList)
    }

    private fun resolveStreamUrl(track: Track): String {
        // For now, return the highest quality thumbnail as URL
        // In a full implementation, this would call InnerTube to get stream URLs
        return track.thumbnails.lastOrNull()?.url ?: ""
    }

    private fun loadMetadata(): List<JSONObject> {
        return loadMetadataMutable()
    }

    private fun loadMetadataMutable(): MutableList<JSONObject> {
        if (!metadataFile.exists()) return mutableListOf()
        return try {
            val text = metadataFile.readText()
            val arr = JSONArray(text)
            (0 until arr.length()).map { arr.getJSONObject(it) }.toMutableList()
        } catch (e: Exception) {
            mutableListOf()
        }
    }

    private fun saveMetadata(track: Track, path: String) {
        val list = loadMetadataMutable()
        list.removeAll { it.optString("videoId") == track.videoId }
        list.add(JSONObject().apply {
            put("videoId", track.videoId)
            put("title", track.title)
            put("artist", track.artist)
            put("albumArtUrl", track.albumArtUrl ?: "")
            put("path", path)
            put("downloadedAt", System.currentTimeMillis())
        })
        saveMetadataList(list)
    }

    private fun saveMetadataList(list: List<JSONObject>) {
        metadataFile.writeText(JSONArray(list).toString())
    }
}
