import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val rootKeystorePropertiesFile = rootProject.file("key.properties")
val appKeystorePropertiesFile = project.file("key.properties")
if (rootKeystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(rootKeystorePropertiesFile))
} else if (appKeystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(appKeystorePropertiesFile))
}

val storeFilePath = keystoreProperties.getProperty("storeFile")
val resolvedStoreFile = when {
    storeFilePath.isNullOrEmpty() -> null
    file(storeFilePath).exists() -> file(storeFilePath)
    rootProject.file(storeFilePath).exists() -> rootProject.file(storeFilePath)
    else -> file(storeFilePath)
}

android {
    namespace = "com.vyavahareyash.cashflow"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.vyavahareyash.cashflow"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keyAliasVal = keystoreProperties.getProperty("keyAlias") ?: System.getenv("PLAY_KEY_ALIAS")
            val keyPasswordVal = keystoreProperties.getProperty("keyPassword") ?: System.getenv("PLAY_KEY_PASSWORD")
            val storePasswordVal = keystoreProperties.getProperty("storePassword") ?: System.getenv("PLAY_KEYSTORE_PASSWORD")
            val targetStoreFile = resolvedStoreFile ?: System.getenv("PLAY_KEYSTORE_PATH")?.let { file(it) }

            if (!keyAliasVal.isNullOrEmpty() && !keyPasswordVal.isNullOrEmpty() && !storePasswordVal.isNullOrEmpty() && targetStoreFile != null && targetStoreFile.exists()) {
                keyAlias = keyAliasVal
                keyPassword = keyPasswordVal
                storePassword = storePasswordVal
                storeFile = targetStoreFile
            }
        }
    }

    buildTypes {
        release {
            ndk {
                debugSymbolLevel = "none"
            }
            val releaseConfig = signingConfigs.getByName("release")
            signingConfig = if (releaseConfig.storeFile != null) {
                releaseConfig
            } else {
                signingConfigs.getByName("debug")
            }
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
