import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Assinatura de release lida de android/key.properties (fora do git — ver .gitignore).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "br.app.jurandir"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // App ID do Google Play. `br.app.jurandir` (conta pessoal antiga) está preso
        // naquela conta; a conta de organização usa este novo App ID. O `namespace`
        // (br.app.jurandir) segue interno — não precisa casar com o applicationId.
        applicationId = "br.app.jurandirgarcomdigital"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        // Play exige targetSdk >= 36 (Android 16) para novos apps/atualizações.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Assina com o keystore de release se houver key.properties; senão cai no
            // debug (permite `flutter run --release` local sem o keystore).
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
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

dependencies {
    // 16 KB page size (exigência do Google Play desde nov/2025). O mobile_scanner
    // 5.2.3 trazia bibliotecas nativas de 4 KB — libbarhopper_v3.so (ML Kit barcode)
    // e libimage_processing_util_jni.so (CameraX). Estas versões alinham os .so a
    // 16 KB. Gradle resolve pelo maior, então sobrepõem as versões antigas do plugin.
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
    implementation("androidx.camera:camera-core:1.4.1")
    implementation("androidx.camera:camera-camera2:1.4.1")
    implementation("androidx.camera:camera-lifecycle:1.4.1")
    implementation("androidx.camera:camera-view:1.4.1")
}
