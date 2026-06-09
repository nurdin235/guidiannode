import java.util.Properties
import java.util.Base64
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { load(it) }
    }
}

val keystoreProperties = Properties().apply {
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

val hasReleaseSigning = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
).all { key -> keystoreProperties.getProperty(key)?.isNotBlank() == true }

fun readDartDefines(): Map<String, String> {
    val rawDefines = providers.gradleProperty("dart-defines").orNull
        ?: return emptyMap()

    return rawDefines
        .split(",")
        .mapNotNull { encodedDefine ->
            runCatching {
                String(Base64.getDecoder().decode(encodedDefine))
            }.getOrNull()
        }
        .mapNotNull { decodedDefine ->
            val parts = decodedDefine.split("=", limit = 2)
            if (parts.size == 2) parts[0] to parts[1] else null
        }
        .toMap()
}

val dartDefines = readDartDefines()
val productionApiBaseUrl =
    dartDefines["API_BASE_URL"]
        ?: dartDefines["VITE_API_BASE_URL"]
        ?: dartDefines["API_AUTH_BASE_URL"]
        ?: ""

fun looksLikeLocalApiUrl(value: String): Boolean {
    val normalizedValue = value.lowercase()
    return listOf("localhost", "127.0.0.1", "10.0.2.2", "192.168.", "10.0.", "172.16.")
        .any { normalizedValue.contains(it) }
}

val googleMapsReleaseApiKey =
    System.getenv("GOOGLE_MAPS_API_KEY")
        ?: System.getenv("VITE_GOOGLE_MAPS_API_KEY")
        ?: localProperties.getProperty("GOOGLE_MAPS_API_KEY")
        ?: localProperties.getProperty("VITE_GOOGLE_MAPS_API_KEY")
        ?: ""

val googleMapsDebugApiKey =
    System.getenv("GOOGLE_MAPS_DEBUG_API_KEY")
        ?: localProperties.getProperty("GOOGLE_MAPS_DEBUG_API_KEY")
        ?: googleMapsReleaseApiKey

android {
    namespace = "com.guardiannode.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    defaultConfig {
        applicationId = "com.guardiannode.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsReleaseApiKey
        manifestPlaceholders["usesCleartextTraffic"] = "false"
    }

    buildTypes {
        debug {
            manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsDebugApiKey
            manifestPlaceholders["usesCleartextTraffic"] = "true"
        }

        release {
            manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsReleaseApiKey
            manifestPlaceholders["usesCleartextTraffic"] = "false"
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

afterEvaluate {
    tasks.matching { task -> task.name == "preReleaseBuild" }.configureEach {
        doFirst {
            if (!hasReleaseSigning) {
                throw GradleException(
                    "Release builds require android/key.properties with storeFile, " +
                        "storePassword, keyAlias, and keyPassword. Create an upload " +
                        "keystore before building for Play Store."
                )
            }

            if (productionApiBaseUrl.isBlank()) {
                throw GradleException(
                    "Release builds require --dart-define=API_BASE_URL=https://<your-production-api>."
                )
            }

            if (!productionApiBaseUrl.startsWith("https://")) {
                throw GradleException(
                    "Release API_BASE_URL must use HTTPS. Current value: $productionApiBaseUrl"
                )
            }

            if (looksLikeLocalApiUrl(productionApiBaseUrl)) {
                throw GradleException(
                    "Release API_BASE_URL cannot point to localhost, emulator, or LAN addresses. " +
                        "Current value: $productionApiBaseUrl"
                )
            }

            if (googleMapsReleaseApiKey.isBlank()) {
                throw GradleException(
                    "Release builds require GOOGLE_MAPS_API_KEY in local.properties or the environment."
                )
            }
        }
    }
}

flutter {
    source = "../.."
}
