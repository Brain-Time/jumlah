import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --- Release-Signing (Task F1) ---
// Liest Alias/Passwoerter aus der (git-ignorierten) android/key.properties.
// Fehlt die Datei (z.B. frisches Clone), faellt der Release-Build auf die
// Debug-Signierung zurueck statt zu scheitern.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.jumlah.jumlah"
    compileSdk = flutter.compileSdkVersion
    // Hoehere Version als flutter.ndkVersion, da in_app_purchase_android und
    // sqflite_android Android NDK 27 voraussetzen (rueckwaertskompatibel).
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            val storeFileValue = keystoreProperties["storeFile"]?.toString()
            if (storeFileValue != null) {
                keyAlias = keystoreProperties["keyAlias"]?.toString()
                keyPassword = keystoreProperties["keyPassword"]?.toString()
                storeFile = file(storeFileValue)
                storePassword = keystoreProperties["storePassword"]?.toString()
            }
        }
    }

    defaultConfig {
        // Task F1: eindeutige Application ID fuer den Play Store vergeben.
        applicationId = "com.jumlah.jumlah"
        // Die folgenden Werte entsprechen dem Flutter-Ziel (siehe pubspec.yaml,
        // versionCode = build number, versionName = Versionsnummer).
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Task F1: Release-Signing aus android/key.properties (sofern
            // vorhanden). Ohne die Datei faellt er auf die Debug-Keys zurueck,
            // damit `flutter run --release` in der Entwicklung weiter funktioniert.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
