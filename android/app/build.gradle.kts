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

// Tuya (2026-10-17): con el paquete de seguridad fuera del repo se compila src/tuyaOn (puente real);
// sin él, src/tuyaOff (contesta TUYA_NOT_LINKED). Las dos carpetas declaran la MISMA clase.
val tuyaSdkVersion = "7.8.0"
val tuyaLinked: Boolean = rootProject.extra["ohmsafeTuyaLinked"] as Boolean
val tuyaSecDir = rootProject.extra["ohmsafeTuyaAndroidSdk"] as java.io.File
logger.lifecycle(if (tuyaLinked) "[ohmsafe] Tuya SDK enlazado desde $tuyaSecDir" else "[ohmsafe] Tuya SDK ausente: build sin emparejamiento Tuya (TUYA_NOT_LINKED)")

// Imou (2026-10-20): con LCOpenSDK.aar fuera del repo se compila src/imouOn (puente real); sin él,
// src/imouOff (contesta IMOU_NOT_LINKED). Las dos carpetas declaran la MISMA clase (como Tuya).
val imouLinked: Boolean = rootProject.extra["ohmsafeImouLinked"] as Boolean
val imouSdkDir = rootProject.extra["ohmsafeImouAndroidSdk"] as java.io.File
logger.lifecycle(if (imouLinked) "[ohmsafe] Imou SDK enlazado desde $imouSdkDir" else "[ohmsafe] Imou SDK ausente: build sin emparejamiento Imou (IMOU_NOT_LINKED)")

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
        if (tuyaLinked) {
            // Varios AAR de Tuya traen las mismas libs nativas (igual que en la app del cliente).
            jniLibs.pickFirsts += listOf("**/libc++_shared.so", "**/libthing*.so", "**/libtt*.so", "**/libyuv.so", "**/libopenssl*.so", "**/libcrypto*.so", "**/libssl*.so")
        }
        if (imouLinked) {
            // El AAR de Imou trae su propio libc++_shared (y los jar de bouncycastle que ya traen EZVIZ/Tuya).
            jniLibs.pickFirsts += listOf("**/libc++_shared.so")
            resources.excludes += setOf("META-INF/versions/9/OSGI-INF/MANIFEST.MF", "META-INF/BC1024KE.*", "META-INF/BC2048KE.*")
        }
        resources.excludes += setOf("META-INF/LICENSE*", "META-INF/NOTICE*", "META-INF/INDEX.LIST", "META-INF/DEPENDENCIES", "META-INF/rxjava.properties")
    }

    sourceSets {
        getByName("main") {
            java.srcDir(if (tuyaLinked) "src/tuyaOn/kotlin" else "src/tuyaOff/kotlin")
            java.srcDir(if (imouLinked) "src/imouOn/kotlin" else "src/imouOff/kotlin")
        }
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

// Copia del AAR de Imou sin proguard.txt (ver dependencies). Sale en build/app/imou/.
val ohmsafeImouAar = tasks.register<Zip>("ohmsafeImouAar") {
    onlyIf { imouLinked }
    if (imouLinked) from(zipTree(File(imouSdkDir, "LCOpenSDK.aar"))) { exclude("proguard.txt") }
    archiveFileName.set("LCOpenSDK-sin-proguard.aar")
    destinationDirectory.set(layout.buildDirectory.dir("imou"))
    entryCompression = ZipEntryCompression.STORED
    isZip64 = true
}

dependencies {
    // EZVIZ Open SDK global (`com.videogo.openapi.EZGlobalSDK`). okhttp y gson los exige el SDK y su POM
    // NO los declara: sin ellos revienta en ejecución (NoClassDefFoundError), no al compilar.
    implementation("io.github.ezviz-open:ezviz-sdk:5.32")
    implementation("com.squareup.okhttp3:okhttp:3.12.1")
    implementation("com.google.code.gson:gson:2.8.5")

    if (imouLinked) {
        // Imou LCOpenSDK (sólo emparejamiento: LCOpenSDK.aar; LCOpenMediaSDK.aar es vídeo y no se enlaza).
        // Se enlaza una copia SIN su proguard.txt: esas reglas (-dontoptimize, -keepparameternames…) se
        // aplican a toda la app como consumer rules y tumban a R8 («Compilation failed to complete»).
        implementation(files(ohmsafeImouAar))
    }

    if (tuyaLinked) {
        // Paquete de seguridad propio de la app: vive FUERA del repo, se trata como el AppSecret.
        implementation(fileTree(mapOf("dir" to tuyaSecDir, "include" to listOf("*.aar"))))
        // Smart Life App SDK (sólo emparejamiento; sin cámaras IPC).
        implementation("com.thingclips.smart:thingsmart:$tuyaSdkVersion")
        implementation("com.alibaba:fastjson:1.1.67.android")
        implementation("com.squareup.okhttp3:okhttp-urlconnection:3.14.9")
    }
}

if (tuyaLinked) {
    // El POM de thingsmart-asynclib pide thingsmart-modularCampAnno:1.0.0-SNAPSHOT, que Tuya no publica;
    // Tuya sí publica 2.8.1 (lo mismo que resolvió la app del cliente).
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.thingclips.smart" && requested.name == "thingsmart-modularCampAnno" && requested.version == "1.0.0-SNAPSHOT") {
                useVersion("2.8.1")
                because("Tuya publica 2.8.1; el SNAPSHOT del POM no existe")
            }
        }
    }
}
