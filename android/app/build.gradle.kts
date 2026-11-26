import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystoreProperties = keystorePropertiesFile.exists()
if (hasKeystoreProperties) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "ir.kifino.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ir.kifino.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val isReleaseTaskRequested = gradle.startParameter.taskNames.any {
                it.contains("release", ignoreCase = true)
            }
            val isCi = System.getenv("CI") == "true"

            if (hasKeystoreProperties) {
                val keyAliasProp = keystoreProperties.getProperty("keyAlias")
                val keyPasswordProp = keystoreProperties.getProperty("keyPassword")
                val storeFileProp = keystoreProperties.getProperty("storeFile")
                val storePasswordProp = keystoreProperties.getProperty("storePassword")

                if (keyAliasProp.isNullOrBlank() ||
                    keyPasswordProp.isNullOrBlank() ||
                    storeFileProp.isNullOrBlank() ||
                    storePasswordProp.isNullOrBlank()
                ) {
                    throw GradleException(
                        "android/key.properties is present but missing required signing properties " +
                            "(keyAlias, keyPassword, storePassword, storeFile)."
                    )
                }

                // Resolve relative to android/app/ first (matches release.yml & key.properties.example),
                // falling back to android/ if the keystore was placed at the root Gradle directory.
                val trimmedStoreFile = storeFileProp.trim()
                val appRelativeStoreFile = file(trimmedStoreFile)
                val rootRelativeStoreFile = rootProject.file(trimmedStoreFile)
                val resolvedStoreFile = when {
                    appRelativeStoreFile.exists() -> appRelativeStoreFile
                    rootRelativeStoreFile.exists() -> rootRelativeStoreFile
                    else -> throw GradleException(
                        "Keystore file '$trimmedStoreFile' declared in android/key.properties was not found. " +
                            "Checked: ${appRelativeStoreFile.absolutePath} and ${rootRelativeStoreFile.absolutePath}"
                    )
                }

                keyAlias = keyAliasProp
                keyPassword = keyPasswordProp
                storeFile = resolvedStoreFile
                storePassword = storePasswordProp
            } else if (isCi && isReleaseTaskRequested &&
                (file("upload-keystore.jks").exists() || rootProject.file("upload-keystore.jks").exists())
            ) {
                throw GradleException(
                    "Found upload-keystore.jks in CI for a release build, but android/key.properties is missing."
                )
            } else {
                // Only fall back to debug signing when key.properties does not exist (local dev builds).
                initWith(signingConfigs.getByName("debug"))
            }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
