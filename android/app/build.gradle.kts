plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.wakeorpay.wake_or_pay"
    // Ahead of flutter.compileSdkVersion on purpose: flutter_secure_storage 11
    // — where the SMTP app password lives — publishes AAR metadata demanding
    // 37, and the build refuses outright below it. Compiling against a newer
    // SDK only makes newer APIs visible; minSdk (26) is what decides which
    // devices can install this, and it has not moved.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications compiles against java.time, which minSdk 26
        // does have — but the library targets lower and the plugin demands the
        // desugaring flag regardless. Without it the release build refuses.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.wakeorpay.wake_or_pay"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        multiDexEnabled = true
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Flutter minifies release with R8; the extra rules cover the
            // unused Stripe push-provisioning bridge (see proguard-rules.pro).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // Theme.MaterialComponents.* — what LaunchTheme / NormalTheme now inherit
    // from, because Stripe's PaymentSheet (カード人質) refuses to inflate under a
    // plain android: theme. Declared here rather than leaned on transitively
    // through stripe_android, so the themes do not break the day that
    // dependency moves.
    implementation("com.google.android.material:material:1.12.0")
}

flutter {
    source = "../.."
}
