import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (F-21): reads android/key.properties, which is gitignored
// and created by Prashant only — the repo never contains a keystore. Without
// it, release builds fall back to the debug key so CI's assembleDebug and
// local smoke builds keep working.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "ch.hoffely.fokus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // D-004: publish as ch.hoffely.fokus under Hoffely GmbH.
        applicationId = "ch.hoffely.fokus"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                // No key.properties on this machine → debug key so local
                // release smoke-builds still work. Play uploads REQUIRE the
                // real key (Prashant-only, F-21).
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Schedule arming (F-13, fokus-specs §3.7): reminder + auto-start work
    // that persists across reboots. D-022.
    implementation("androidx.work:work-runtime-ktx:2.9.1")
    // JVM unit tests for the pure blocking-core logic (CONVENTIONS testing bar).
    testImplementation("junit:junit:4.13.2")
    // Real org.json on the test classpath (android.jar's is a throwing stub) so
    // the pure JournalCore (D-013 P1-A) is testable without Robolectric.
    testImplementation("org.json:json:20240303")
}
