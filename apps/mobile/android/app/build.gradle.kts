import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── FCM / google-services guard (Task B2) ─────────────────────────────────────
// The plugin is applied ONLY when the real google-services.json exists — CI
// (and fresh clones) must build WITHOUT it. Copy google-services.example.json
// → google-services.json and fill the real values (docs/RELEASE.md §Firebase).
// The Flutter firebase_* plugins initialize from lib/firebase_options.dart
// (flutterfire configure), so the JSON itself is optional for the build.
val googleServicesJson = file("google-services.json")
if (googleServicesJson.exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "bd.asunnah.sunnah_life"
    compileSdk = flutter.compileSdkVersion
    // Pinned to Flutter's blessed NDK: AGP 9.1 demands an NDK at configure
    // time (its default IS this version) for the jniLibs strip machinery —
    // auto-installed on CI runners. Debug builds skip actual stripping via the
    // keepDebugSymbols block below.
    ndkVersion = flutter.ndkVersion

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
            // Release signing from android/key.properties when present
            // (CI injects it from secrets — see docs/RELEASE.md §3); falls
            // back to debug signing so local `flutter run --release` works.
            val keystoreProperties = Properties()
            val keystorePropertiesFile = rootProject.file("key.properties")
            val hasReleaseKeystore = keystorePropertiesFile.exists()
            if (hasReleaseKeystore) {
                keystoreProperties.load(keystorePropertiesFile.inputStream())
            }
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.create("release") {
                    keyAlias = keystoreProperties["keyAlias"] as String
                    keyPassword = keystoreProperties["keyPassword"] as String
                    storeFile = file(keystoreProperties["storeFile"] as String)
                    storePassword = keystoreProperties["storePassword"] as String
                }
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

// Debug APKs keep native symbols by design — the strip task's llvm-strip would
// drag in a 2+ GB NDK download for zero debugging value. Scoped to the debug
// variant only: release keeps the default stripping (CI runners provide the
// NDK there).
androidComponents {
    onVariants(selector().withBuildType("debug")) { variant ->
        variant.packaging.jniLibs.keepDebugSymbols.add("**/*.so")
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
