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
    // auto-installed on CI runners. Debug and release both strip normally
    // (the old debug-only keepDebugSymbols escape hatch was removed in W3i —
    // CI runners have the NDK, and the sandbox never runs gradle).
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
        // ABI selection is owned by the Flutter tool, not by abiFilters: debug
        // APKs ship every engine ABI regardless of any filter here (proven on
        // run #25's 3-ABI debug artifact), and the release split is driven by
        // `flutter build apk --release --split-per-abi
        // --target-platform android-arm,android-arm64` (the release-apk CI
        // job). A defaultConfig abiFilters line was a misleading no-op —
        // removed in W3i.
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

// (W3i) the debug-only keepDebugSymbols block is GONE: CI runners provide
// the NDK for normal stripping on both variants, and the debug APK artifact
// shrinks accordingly. R8/minify is deliberately NOT enabled yet — the
// split alone meets the < 40 MB arm64 target, and shrinking/obfuscation
// needs a device smoke before it can be trusted with plugin reflection
// (workmanager, notification receivers). Revisit after the owner's device
// round.

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
