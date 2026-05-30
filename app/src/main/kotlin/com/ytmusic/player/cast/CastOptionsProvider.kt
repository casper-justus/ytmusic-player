package com.ytmusic.player.cast

import com.google.android.gms.cast.framework.CastOptions
import com.google.android.gms.cast.framework.OptionsProvider
import com.google.android.gms.cast.framework.SessionProvider
import com.google.android.gms.cast.framework.media.CastMediaOptions
import com.google.android.gms.cast.framework.media.MediaIntentReceiver
import com.google.android.gms.cast.framework.media.NotificationOptions

class CastOptionsProvider : OptionsProvider {

    override fun getCastOptions(context: android.content.Context): CastOptions {
        val notificationOptions = NotificationOptions.Builder()
            .setTargetActivityClassName(com.ytmusic.player.ui.player.PlayerActivity::class.java.name)
            .build()

        val mediaOptions = CastMediaOptions.Builder()
            .setNotificationOptions(notificationOptions)
            .build()

        return CastOptions.Builder()
            .setReceiverApplicationId("CC1AD845") // Default Cast receiver
            .setCastMediaOptions(mediaOptions)
            .setEnableReconnectionService(true)
            .build()
    }

    override fun getAdditionalSessionProviders(context: android.content.Context): MutableList<SessionProvider>? {
        return null
    }
}
