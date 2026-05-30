package com.ytmusic.player.cast

import android.content.Context
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.common.api.PendingResult
import com.google.android.gms.common.api.ResultCallback
import com.ytmusic.player.data.model.Track

class CastManager(context: Context) {

    private val castContext: CastContext = CastContext.getSharedInstance(context)
    private var currentSession: CastSession? = null
    private val listeners = mutableListOf<CastListener>()

    val isConnected: Boolean get() = currentSession?.isConnected == true
    val deviceName: String? get() = currentSession?.castDevice?.friendlyName

    private val sessionListener = object : SessionManagerListener<CastSession> {
        override fun onSessionStarting(p0: CastSession?) {}
        override fun onSessionStarted(p0: CastSession?, p1: String?) {
            currentSession = p0
            listeners.forEach { it.onConnected(p0?.castDevice?.friendlyName ?: "Cast Device") }
        }
        override fun onSessionStartFailed(p0: CastSession?, p1: Int) {
            listeners.forEach { it.onError("Failed to connect") }
        }
        override fun onSessionEnding(p0: CastSession?) {}
        override fun onSessionEnded(p0: CastSession?, p1: Int) {
            currentSession = null
            listeners.forEach { it.onDisconnected() }
        }
        override fun onSessionResuming(p0: CastSession?, p1: String?) {}
        override fun onSessionResumed(p0: CastSession?, p1: Boolean) {
            currentSession = p0
        }
        override fun onSessionResumeFailed(p0: CastSession?, p1: Int) {}
        override fun onSessionSuspended(p0: CastSession?, p1: Int) {}
    }

    init {
        castContext.sessionManager.addSessionManagerListener(sessionListener, CastSession::class.java)
        currentSession = castContext.sessionManager.currentCastSession
    }

    fun addListener(listener: CastListener) = listeners.add(listener)
    fun removeListener(listener: CastListener) = listeners.remove(listener)

    fun loadTrack(track: Track) {
        // Cast track loading would be implemented with RemoteMediaClient
        // For now, this is a placeholder for future implementation
    }

    fun disconnect() {
        castContext.sessionManager.endCurrentSession(true)
    }

    interface CastListener {
        fun onConnected(deviceName: String) {}
        fun onDisconnected() {}
        fun onError(message: String) {}
    }
}
