plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.app_aprendizaje"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.app_aprendizaje"
        minSdk = 23
        targetSdk = 35

        // Kotlin DSL usa '='
        multiDexEnabled = true

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    ndkVersion = "27.0.12077973"

    compileOptions {
        // Kotlin DSL: 'isCoreLibraryDesugaringEnabled'
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug { /* default */ }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Kotlin DSL usa comillas y función
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // opcional: suele venir por el plugin, pero no estorba
    implementation("org.jetbrains.kotlin:kotlin-stdlib")
}
