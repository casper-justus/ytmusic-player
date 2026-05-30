# ProGuard rules for YTMusic Player
-keepattributes Signature
-keepattributes *Annotation*

# Keep data model classes
-keep class com.ytmusic.player.data.model.** { *; }

# Keep Gson/JSON parsing
-keep class com.google.gson.** { *; }
-keepattributes EnclosingMethod

# Keep Glide
-keep class com.bumptech.glide.** { *; }

# Keep OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep Cast SDK
-keep class com.google.android.gms.cast.** { *; }
