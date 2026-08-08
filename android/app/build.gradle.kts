import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.allldown.tajer"

    val localProperties = Properties()
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.reader().use { reader ->
            localProperties.load(reader)
        }
    }

    val flutterVersionCode = localProperties.getProperty("flutter.versionCode")?.toIntOrNull() ?: 1
    val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"
    val flutterCompileSdk = localProperties.getProperty("flutter.compileSdkVersion")?.toIntOrNull() ?: 36
    val flutterTargetSdk = localProperties.getProperty("flutter.targetSdkVersion")?.toIntOrNull() ?: 36
    val signingProperties = Properties()
    val signingPropertiesFile = rootProject.file("key.properties")
    if (signingPropertiesFile.exists()) {
        signingPropertiesFile.reader().use { reader ->
            signingProperties.load(reader)
        }
    }

    fun signingValue(name: String): String? =
        (System.getenv("TAJER_${name.uppercase()}") ?: signingProperties.getProperty(name))
            ?.trim()
            ?.takeIf { it.isNotEmpty() }

    compileSdk = 36
    ndkVersion = "28.2.13676358"

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
        targetSdk = 36
        versionCode = flutterVersionCode
        versionName = flutterVersionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = signingValue("storeFile")
                ?: throw GradleException("Missing release signing storeFile. Provide TAJER_STOREFILE or key.properties.")
            storeFile = file(storeFilePath)
            storePassword = signingValue("storePassword")
                ?: throw GradleException("Missing release signing storePassword.")
            keyAlias = signingValue("keyAlias")
                ?: throw GradleException("Missing release signing keyAlias.")
            keyPassword = signingValue("keyPassword")
                ?: throw GradleException("Missing release signing keyPassword.")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
