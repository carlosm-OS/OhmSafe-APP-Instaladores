import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase: procesa google-services.json (FCM push).
    id("com.google.gms.google-services")
}

// Llave de SUBIDA a Google Play (Play App Signing firma lo que instalan los usuarios).
// `android/key.properties` NO va en git: vive sólo en la copia de build (ver docs/publicacion-android.md).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val tieneLlaveRelease = keystorePropertiesFile.exists()
if (tieneLlaveRelease) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.ohmsafe.instalador"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.ohmsafe.instalador"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (tieneLlaveRelease) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    // EZVIZ Open SDK global (2026-10-17): sin paquete privado, sale entero de Maven Central. El AAR trae
    // mbedTLS, iconv, SRT y JNA propios; hoy nada choca, la lista evita que un AAR nuevo tumbe el merge.
    packaging {
        jniLibs.pickFirsts += listOf("**/libmbedcrypto.so", "**/libmbedtls.so", "**/libmbedx509.so", "**/libiconv.so", "**/libsrt.so", "**/libjnidispatch.so")
        resources.excludes += setOf("META-INF/LICENSE*", "META-INF/NOTICE*", "META-INF/INDEX.LIST", "META-INF/DEPENDENCIES")
    }

    buildTypes {
        release {
            // Con key.properties se firma con la llave de subida; sin ella (simulador, CI sin secretos)
            // se firma con la de debug para que `flutter run --release` siga funcionando.
            signingConfig = if (tieneLlaveRelease) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // EZVIZ Open SDK global (`com.videogo.openapi.EZGlobalSDK`). okhttp y gson los exige el SDK y su POM
    // NO los declara: sin ellos revienta en ejecución (NoClassDefFoundError), no al compilar.
    implementation("io.github.ezviz-open:ezviz-sdk:5.32")
    implementation("com.squareup.okhttp3:okhttp:3.12.1")
    implementation("com.google.code.gson:gson:2.8.5")
}
