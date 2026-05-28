package com.ytmusic.player

import android.content.ContentUris
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import org.json.JSONArray
import org.json.JSONObject

class MediaStoreHandler(private val context: Context) {

    fun scanAudio(): String {
        val tracks = JSONArray()
        val uri: Uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.ALBUM_ID,
        )
        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
        val sortOrder = "${MediaStore.Audio.Media.TITLE} ASC"

        val cursor = context.contentResolver.query(
            uri, projection, selection, null, sortOrder
        )

        cursor?.use { c ->
            val idCol = c.getColumnIndex(MediaStore.Audio.Media._ID)
            val titleCol = c.getColumnIndex(MediaStore.Audio.Media.TITLE)
            val artistCol = c.getColumnIndex(MediaStore.Audio.Media.ARTIST)
            val albumCol = c.getColumnIndex(MediaStore.Audio.Media.ALBUM)
            val durationCol = c.getColumnIndex(MediaStore.Audio.Media.DURATION)
            val dataCol = c.getColumnIndex(MediaStore.Audio.Media.DATA)
            val albumIdCol = c.getColumnIndex(MediaStore.Audio.Media.ALBUM_ID)

            while (c.moveToNext()) {
                val id = if (idCol >= 0) c.getLong(idCol) else 0L
                val title = if (titleCol >= 0) c.getString(titleCol) ?: "Unknown" else "Unknown"
                val artist = if (artistCol >= 0) c.getString(artistCol) ?: "Unknown Artist" else "Unknown Artist"
                val album = if (albumCol >= 0) c.getString(albumCol) else null
                val durationMs = if (durationCol >= 0) c.getInt(durationCol) else 0
                val dataPath = if (dataCol >= 0) c.getString(dataCol) else null
                val albumId = if (albumIdCol >= 0) c.getLong(albumIdCol) else 0L

                val contentUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    ContentUris.withAppendedId(
                        MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL),
                        id
                    ).toString()
                } else {
                    Uri.withAppendedPath(
                        MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                        id.toString()
                    ).toString()
                }

                val track = JSONObject().apply {
                    put("id", id.toString())
                    put("title", title)
                    put("artist", artist)
                    put("album", album ?: JSONObject.NULL)
                    put("durationMs", durationMs)
                    put("localPath", dataPath ?: JSONObject.NULL)
                    put("contentUri", contentUri)
                    put("albumId", albumId)
                }
                tracks.put(track)
            }
        }

        return tracks.toString()
    }
}
