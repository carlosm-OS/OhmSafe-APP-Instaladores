// Tuya Smart Life App SDK (2026-10-17: emparejar sensores/cámaras Tuya). Los repos Maven de Tuya se
// agregan SÓLO si el paquete de seguridad propio de la app (security-algorithm*.aar, generado por la
// consola de Tuya para com.ohmsafe.instalador) existe fuera del repo; sin él la app compila igual y
// el puente contesta TUYA_NOT_LINKED.
val ohmsafeTuyaAndroidSdk: java.io.File = file(
    System.getenv("OHMSAFE_TUYA_ANDROID_SDK")
        ?: "${System.getProperty("user.home")}/dev/ohmsafe/keys/tuya-instalador/android/sec"
)
val ohmsafeTuyaLinked: Boolean = System.getenv("OHMSAFE_TUYA") != "0" &&
    ohmsafeTuyaAndroidSdk.isDirectory &&
    (ohmsafeTuyaAndroidSdk.listFiles { _, name -> name.endsWith(".aar") }?.isNotEmpty() == true)
extra["ohmsafeTuyaAndroidSdk"] = ohmsafeTuyaAndroidSdk
extra["ohmsafeTuyaLinked"] = ohmsafeTuyaLinked

// Imou LCOpenSDK (2026-10-20: emparejar cámaras Imou desde la app, build 52). El AAR se descarga de la
// consola de Imou y vive FUERA del repo (74 MB, descarga no verificable); sin él se compila src/imouOff
// y el puente contesta IMOU_NOT_LINKED. Ver docs/camaras-imou.md.
val ohmsafeImouAndroidSdk: java.io.File = file(
    System.getenv("OHMSAFE_IMOU_ANDROID_SDK")
        ?: "${System.getProperty("user.home")}/dev/ohmsafe/keys/imou-sdk/android"
)
val ohmsafeImouLinked: Boolean = System.getenv("OHMSAFE_IMOU") != "0" &&
    File(ohmsafeImouAndroidSdk, "LCOpenSDK.aar").isFile
extra["ohmsafeImouAndroidSdk"] = ohmsafeImouAndroidSdk
extra["ohmsafeImouLinked"] = ohmsafeImouLinked

allprojects {
    repositories {
        google()
        mavenCentral()
        if (ohmsafeTuyaLinked) {
            maven { setUrl("https://maven-other.tuya.com/repository/maven-releases/") }
            maven { setUrl("https://maven-other.tuya.com/repository/maven-commercial-releases/") }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Algunos plugins (file_picker) declaran compileSdk 34 y flutter_plugin_android_lifecycle exige 36:
// se nivela a 36 en todas las librerías. Sólo cambia contra qué API se compila, no minSdk/targetSdk.
subprojects {
    val nivelarCompileSdk: Project.() -> Unit = {
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)?.let { ext ->
            if ((ext.compileSdk ?: 0) < 36) ext.compileSdk = 36
        }
    }
    // `evaluationDependsOn(":app")` ya evaluó :app cuando llegamos aquí: no admite afterEvaluate.
    if (project.state.executed) project.nivelarCompileSdk() else afterEvaluate { nivelarCompileSdk() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
