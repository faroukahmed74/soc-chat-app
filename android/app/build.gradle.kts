import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.faroukahmed74.socchatapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        // Updated to match iOS bundle identifier
        applicationId = "com.faroukahmed74.socchatapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            } else {
                // Fallback to debug keystore if key.properties not found
                val localDebugKeystore = file("debug.keystore")
                if (localDebugKeystore.exists()) {
                    storeFile = localDebugKeystore
                    println("[signingConfigs] Using local debug.keystore for release signing")
                } else {
                    val userProfile = System.getenv("USERPROFILE") ?: System.getProperty("user.home")
                    val globalDebugKeystorePath = "$userProfile/.android/debug.keystore"
                    val globalDebugKeystore = file(globalDebugKeystorePath)
                    if (globalDebugKeystore.exists()) {
                        storeFile = globalDebugKeystore
                        println("[signingConfigs] Using global debug.keystore: $globalDebugKeystorePath")
                    } else {
                        println("[signingConfigs] WARNING: debug.keystore not found locally or globally. Build may fail.")
                        storeFile = localDebugKeystore // keep default path
                    }
                }
                storePassword = "android"
                // Default Android debug keystore alias is 'AndroidDebugKey'
                keyAlias = "AndroidDebugKey"
                keyPassword = "android"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Apply Google Services plugin only if configuration file exists
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    println("[build.gradle.kts] Skipping Google Services plugin: google-services.json not found")
}
