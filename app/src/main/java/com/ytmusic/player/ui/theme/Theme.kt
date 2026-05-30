package com.ytmusic.player.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable

private val DarkColorScheme = darkColorScheme(
    background = DarkBackground,
    surface = DarkSurface,
    surfaceVariant = DarkSurfaceVariant,
    primary = PrimaryRed,
    onBackground = OnDark,
    onSurface = OnDark,
    onSurfaceVariant = OnDarkSecondary,
    secondary = OnDarkSecondary,
)

@Composable
fun YTMusicTheme(
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        content = content
    )
}
