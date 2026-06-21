# Flutter / Dart
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }

# mobile_scanner / ZXing
-keep class com.google.zxing.** { *; }

# Prevent stripping serializable classes
-keepattributes Signature
-keepattributes *Annotation*

# OkHttp (used by Dio internally) + WebSocket
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }
-dontwarn okio.**
-keep class okio.** { *; }

# Stockfish native library (JNI bridge — keep the method names intact)
-keep class com.github.bhlangonijr.chesslib.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# Dio / http_parser
-keep class com.squareup.okhttp3.** { *; }
-dontwarn com.squareup.okhttp3.**

# Flutter Play Store Split compatibility (deferred components) fallback
-dontwarn com.google.android.play.core.**
