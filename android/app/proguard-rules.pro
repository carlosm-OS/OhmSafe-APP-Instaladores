# Reglas de ofuscación de la app. Flutter, Firebase y los plugins traen las suyas (consumer rules).
# Conservar las clases de los plugins que se registran por reflexión.
-keep class io.flutter.plugins.** { *; }
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**

# EZVIZ Open SDK (2026-10-17). El AAR trae un proguard.txt VACÍO: sin estas reglas R8 renombra
# com.videogo.** y el SDK (reflexión + JNI) falla en release con ClassNotFoundException.
-keep class com.ezviz.** { *; }
-keep interface com.ezviz.** { *; }
-keep class com.videogo.** { *; }
-keep interface com.videogo.** { *; }
-keep class com.hc.CASClient.** { *; }
-keep class com.hik.** { *; }
-keep class com.hikvision.** { *; }
-keep class com.neutral.netsdk.** { *; }
-keep class com.mediaplayer.audio.** { *; }
-keep class org.MediaPlayer.PlayM4.** { *; }
-keep class com.ez.** { *; }
-keep class com.eziot.** { *; }
-keep class com.sun.jna.** { *; }
-keepclassmembers class * extends com.sun.jna.** { public *; }
-keepclasseswithmembernames class * { native <methods>; }
-dontwarn com.ezviz.mediarecoder.R$*
-dontwarn com.hikvision.audio.**
-dontwarn java.awt.**
-dontwarn javax.jmdns.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses,EnclosingMethod
