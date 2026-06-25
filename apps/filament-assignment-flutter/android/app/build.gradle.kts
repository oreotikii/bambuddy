import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

fun keystoreProperty(name: String): String =
    keystoreProperties.getProperty(name)
        ?: throw GradleException("Missing '$name' in ${keystorePropertiesFile.path}")

fun keystoreFile(path: String): File {
    val file = File(path)
    return if (file.isAbsolute) file else File(keystorePropertiesFile.parentFile, path)
}

gradle.taskGraph.whenReady {
    val hasReleaseBuildTask = allTasks.any { task ->
        task.path == ":app:bundleRelease" || task.path == ":app:assembleRelease"
    }
    if (hasReleaseBuildTask && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "Release signing requires ${keystorePropertiesFile.path}. " +
                "Copy key.properties.example to key.properties and point storeFile at your release keystore.",
        )
    }
}

android {
    namespace = "cool.bambudy.assignfilament"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "cool.bambudy.assignfilament"
        // Match the original native app (Android 8.0+).
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperty("keyAlias")
                keyPassword = keystoreProperty("keyPassword")
                storeFile = keystoreFile(keystoreProperty("storeFile"))
                storePassword = keystoreProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
