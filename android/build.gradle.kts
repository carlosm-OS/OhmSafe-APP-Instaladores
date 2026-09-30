allprojects {
    repositories {
        google()
        mavenCentral()
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
