plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "bd.asunnah.sunnah_life"
    compileSdk = flutter.compileSdkVersion
    // No pinned ndkVersion: debug APKs keep native symbols (see packaging block
    // below) so the build needs no NDK; release/CI builds install it.

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time APIs → required below minSdk 26.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "bd.asunnah.sunnah_life"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Single-ABI debug builds (low-disk CI/sandbox): the debug engine
        // ships ~150 MB per ABI unstripped. The release pipeline builds all
        // ABIs via `flutter build apk --split-per-abi`.
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    // Strip via the NDK's llvm-strip (in constrained environments the NDK
    // toolchain binaries are symlinked to the host binutils, which handle
    // arm64 ELF cross-platform). The Vulkan validation layer (238 MB,
    // Impeller graphics debugging only) is never needed in the field.
    packaging {
        jniLibs {
            excludes += "**/libVkLayer_khronos_validation.so"
        }
    }

    buildTypes {
        release {
            // Debug signing so `flutter run --release` works locally; the
            // store signature is injected by the CI release pipeline.
            signingConfig = signingConfigs.getByName("debug")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
