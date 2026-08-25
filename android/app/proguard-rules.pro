# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Plugin: blue_thermal_printer
-keep class com.sam_oskar.blue_thermal_printer.** { *; }

# Plugin: mobile_scanner (and underlying ML Kit)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.ml.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.zaihui.mobile_scanner.** { *; }

# Plugin: flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Plugin: sqflite
-keep class com.tekartik.sqflite.** { *; }

# Plugin: pdf / printing
-keep class net.nfet.flutter.printing.** { *; }

# Plugin: path_provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# General Android / Google
-keep class com.google.android.gms.** { *; }
-keep class androidx.lifecycle.** { *; }
-dontwarn com.google.android.play.core.**

# Speech to Text / TTS
-keep class com.csdcorp.speech_to_text.** { *; }
-keep class com.tundralabs.flutter_tts.** { *; }

# Support for Kotlin reflection/coroutines if used by plugins
-keep class kotlin.reflect.jvm.internal.** { *; }

# ARVION App Native Classes
-keep class com.arvion.dukanedge.** { *; }
