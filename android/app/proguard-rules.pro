# Flutter and plugin entry points are registered by generated Android code.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class androidx.lifecycle.** { *; }

# Flutter references Play Store deferred components optionally; this app does
# not use deferred Android feature modules.
-dontwarn com.google.android.play.core.**
