plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.allldown.tajer"

    val localProperties = java.util.Properties()
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.reader().use { reader ->
            localProperties.load(reader)
        }
    }

    val flutterVersionCode = localProperties.getProperty("flutter.versionCode")?.toIntOrNull() ?: 1
    val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"
    val flutterCompileSdk = localProperties.getProperty("flutter.compileSdkVersion")?.toIntOrNull() ?: 34
    val flutterTargetSdk = localProperties.getProperty("flutter.targetSdkVersion")?.toIntOrNull() ?: 34
    val flutterNdkVersion = localProperties.getProperty("flutter.ndkVersion") ?: "25.1.8937393"

    compileSdk = flutterCompileSdk
    ndkVersion = flutterNdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.allldown.tajer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutterTargetSdk
        versionCode = flutterVersionCode
        versionName = flutterVersionName
    }

    signingConfigs {
        create("release") {
            storeFile = file("tajer-release.jks")
            storePassword = "tajer123"
            keyAlias = "tajer"
            keyPassword = "tajer123"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
