# Reglas de ofuscación de la app. Flutter, Firebase y los plugins traen las suyas (consumer rules).
# Conservar las clases de los plugins que se registran por reflexión.
-keep class io.flutter.plugins.** { *; }
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
