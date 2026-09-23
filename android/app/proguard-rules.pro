# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# SQFlite
-keep class com.tekartik.sqflite.** { *; }

# llama_cpp_dart native
-keep class com.example.llama_cpp_dart.** { *; }
-keep class ffi.** { *; }

# AndroidX Biometric
-keep class androidx.biometric.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
