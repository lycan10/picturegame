# Release (R8) keep rules for Picture Match.
#
# The Flutter gradle plugin injects rules for the Flutter embedding and the
# Firebase/GMA SDKs ship their own consumer rules — these cover the gaps that
# are specific to this app's plugins. Everything here exists because those
# classes are reached reflectively (or via JSON), which R8 would otherwise
# strip, causing release-only crashes that never appear in debug builds.

# General attributes needed by libraries that read class metadata.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses, EnclosingMethod

# ---------------------------------------------------------------------------
# AdMob (google_mobile_ads): the GMA SDK resolves mediation adapters and some
# internals reflectively; explicit keeps prevent release-only ClassNotFound
# crashes. Also keep our NativeAdFactory implementation — the plugin calls it
# across the platform channel boundary.
# ---------------------------------------------------------------------------
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.internal.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
-keep class * implements io.flutter.plugins.googlemobileads.NativeAdFactory { *; }
-keep class com.example.picture_match.MainActivity { *; }

# ---------------------------------------------------------------------------
# WorkManager (pulled in by Firebase Messaging): its default initializer
# builds the Room-backed WorkDatabase via reflection on the generated
# `WorkDatabase_Impl` classes. R8 full mode renames them, and the
# androidx.startup provider then fails before Flutter runs — a launch crash.
# Keep WorkManager's internals and any Room database implementation.
# ---------------------------------------------------------------------------
-keep class androidx.work.** { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-dontwarn androidx.room.**

# ---------------------------------------------------------------------------
# flutter_local_notifications: recommended Gson/shrink rules from the plugin
# docs (v19+ ships most of its own rules; these attributes keep the scheduled
# notification payloads intact when deserializing after a reboot).
# ---------------------------------------------------------------------------
-keep class com.dexterous.** { *; }
-dontwarn sun.misc.**
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# ---------------------------------------------------------------------------
# Plugins that deserialize models across the method channel — keep their
# fields so JSON binding doesn't null out data members.
# ---------------------------------------------------------------------------
-keep class com.abedalkareem.games_services.** { *; }

# Flutter secure storage: keep the cipher/keystore helpers reachable.
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Silence references pulled in by plugin dependency graphs that are only used
# on platforms we don't build for.
-dontwarn java.nio.file.Files
-dontwarn java.nio.file.Path
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement
