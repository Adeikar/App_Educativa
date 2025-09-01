pluginManagement {

    val props = java.util.Properties().apply {
        val f = file("local.properties")
        if (f.exists()) f.inputStream().use { load(it) }
    }
    val flutterSdk: String = props.getProperty("flutter.sdk")
        ?: throw GradleException("Falta 'flutter.sdk' en local.properties (ej: C:\\\\src\\\\flutter)")

    includeBuild("$flutterSdk/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }


    plugins {
        id("com.android.application") version "8.7.3"
        id("com.android.library") version "8.7.3"
        id("org.jetbrains.kotlin.android") version "1.9.24"
        id("com.google.gms.google-services") version "4.4.2"
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Declaramos pero NO aplicamos estos aquí
    id("com.android.application") apply false
    id("org.jetbrains.kotlin.android") apply false
    id("com.google.gms.google-services") apply false
}

include(":app")
