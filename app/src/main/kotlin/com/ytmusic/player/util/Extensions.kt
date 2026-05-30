package com.ytmusic.player.util

import android.graphics.Bitmap
import android.graphics.Color
import android.widget.ImageView
import androidx.core.graphics.drawable.toBitmap
import com.bumptech.glide.Glide
import com.bumptech.glide.load.DataSource
import com.bumptech.glide.load.engine.GlideException
import com.bumptech.glide.request.RequestListener
import com.bumptech.glide.request.target.Target
import java.text.DecimalFormat
import java.util.Locale

fun Long.formatDuration(): String {
    val totalSec = this / 1000
    val min = totalSec / 60
    val sec = totalSec % 60
    return "%d:%02d".format(min, sec)
}

fun Int?.orZero(): Int = this ?: 0

fun String?.orEmpty(): String = this ?: ""

fun loadImage(url: String?, imageView: ImageView, placeholder: Int? = null) {
    val req = Glide.with(imageView)
        .load(url)
    if (placeholder != null) {
        req.placeholder(placeholder)
        req.error(placeholder)
    }
    req.into(imageView)
}

fun getDominantColor(bitmap: Bitmap): Int {
    var r = 0; var g = 0; var b = 0; var count = 0
    val step = maxOf(1, bitmap.width * bitmap.height / 400)
    for (x in 0 until bitmap.width step step) {
        for (y in 0 until bitmap.height step step) {
            val pixel = bitmap.getPixel(x, y)
            r += Color.red(pixel)
            g += Color.green(pixel)
            b += Color.blue(pixel)
            count++
        }
    }
    return if (count > 0) Color.rgb(r / count, g / count, b / count) else Color.BLACK
}
