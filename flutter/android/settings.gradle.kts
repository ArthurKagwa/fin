pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Pinned to 8.x, below the 9.0.1 the Flutter template generated.
    //
    // On AGP 9 this project's plugin set has no working configuration:
    //   - android.builtInKotlin=false: file_picker 11.0.3 keys only off the
    //     AGP major version, skips applying KGP, and its Kotlin-only
    //     FilePickerPlugin never gets compiled into the AAR.
    //   - android.builtInKotlin=true: cloud_firestore 6.7.1 applies
    //     org.jetbrains.kotlin.android unconditionally, which AGP 9 rejects
    //     ("no longer required for Kotlin support since AGP 9.0").
    //
    // On AGP 8 both apply KGP the ordinary way and compile. 8.11.1 is also
    // the minimum flutter_local_notifications documents.
    //
    // Revisit once file_picker honours android.builtInKotlin and
    // cloud_firestore stops applying KGP unconditionally.
    id("com.android.application") version "8.11.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.4.4") apply false
    id("com.google.firebase.crashlytics") version("3.0.7") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
