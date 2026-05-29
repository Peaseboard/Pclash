# PClash ProGuard Rules
# Keep Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }

# Keep our VPN service
-keep class com.pclash.app.** { *; }

# Keep model classes for JSON serialization
-keep class com.pclash.app.models.** { *; }

# Don't warn about referenced classes
-dontwarn io.flutter.embedding.**
-dontwarn org.intellij.lang.annotations.**
-dontwarn org.jetbrains.annotations.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
