import java.io.File

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// v2.0 installs over v1.x: the same application ID, the same key and a higher versionCode (CI passes
// --build-number). Google Play: the app bundle is signed with an upload key that never enters this public repo; CI
// writes it from the secret XC_UPLOAD_KEYSTORE_B64 and passes its path and passwords as environment variables.
// Without them (forks, local builds) the bundle falls back to the old sideload key (don't upload that one).
val upStore: String? = System.getenv("XC_UPLOAD_KEYSTORE")
val hasUpload = upStore != null && File(upStore).exists()

android {
    namespace = "com.armstrang.xueci"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.armstrang.xueci"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // One fixed key for every sideload build: Android only accepts an update signed with the same key.
        create("merdeka") {
            storeFile = rootProject.file("../../keystore/xueci.jks")
            storePassword = "merdekamandarin"
            keyAlias = "merdeka"
            keyPassword = "merdekamandarin"
        }
        if (hasUpload) {
            create("upload") {
                storeFile = File(upStore!!)
                storePassword = System.getenv("XC_UPLOAD_STORE_PASSWORD")
                keyAlias = System.getenv("XC_UPLOAD_KEY_ALIAS")
                keyPassword = System.getenv("XC_UPLOAD_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (System.getenv("XC_PLAY") == "1" && hasUpload) "upload" else "merdeka")
        }
        debug {
            signingConfig = signingConfigs.getByName("merdeka")
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.webkit:webkit:1.12.1")
    implementation("androidx.core:core-splashscreen:1.0.1")
}

flutter {
    source = "../.."
}
