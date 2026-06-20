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

# OkHttp (used by Dio internally)
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }

# Flutter Play Store Split compatibility (deferred components) fallback
-dontwarn com.google.android.play.core.**

