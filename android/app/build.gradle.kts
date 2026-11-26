import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // Plugin Flutter Gradle harus diterapkan setelah plugin Android dan Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.netri.exam.netri_exam"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.netri.exam.netri_exam"
        minSdk = flutter.minSdkVersion
        // Gunakan targetSdk 34 (Android 14 stabil) agar lolos parser paket seluruh OEM termasuk Vivo
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Sertakan hanya arsitektur prosesor HP Android asli agar ukuran APK ramping dan aman diunduh via WA
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    packaging {
        jniLibs {
            // Kompresi pustaka native agar diekstrak bersih oleh PackageInstaller Vivo/Oppo/Android 15
            useLegacyPackaging = true
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    buildTypes {
        release {
            // Hindari obfuskasi DEX yang kerap memicu deteksi palsu pemindai keamanan OEM
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
