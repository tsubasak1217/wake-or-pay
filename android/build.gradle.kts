allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// stripe_android's Kotlin compiles to the same bytecode its Java does.
//
// カード人質 (docs/BILLING_API.md) pulled in stripe_android, whose own Gradle
// file pins `compileOptions` to Java 17 but leaves `jvmTarget` unset — so
// Kotlin follows the JDK running Gradle (25 here) and the build stops with
// 「Inconsistent JVM-target compatibility … 'compileDebugJavaWithJavac' (17)
// and 'compileDebugKotlin' (25)」.
//
// **Named, not blanket.** Applying 17 to every subproject breaks the plugins
// that are internally consistent at some other level: flutter_tts compiles its
// Java at 11, and forcing its Kotlin to 17 fails with the same error the other
// way round. Each plugin's two halves must agree with *each other*, not with
// the app.
//
// **Above the `evaluationDependsOn(":app")` block on purpose**: that one forces
// :app to evaluate as it runs, and `afterEvaluate` on an already-evaluated
// project is an error.
subprojects {
    if (name == "stripe_android") {
        afterEvaluate {
            extensions
                .findByType(org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java)
                ?.compilerOptions
                ?.jvmTarget
                ?.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)

        }

        // Keep `play-services-tapandpay` off stripe_android's *lint* classpath.
        //
        // Its transitive `stripe-android-issuing-push-provisioning` declares
        // that Google SDK, which is not on any public Maven repository. The
        // compile classpath never fetches it (the plugin does not use push
        // provisioning), but `lintVitalAnalyzeRelease` — run by the app's
        // release build for every library — resolves the lint checks classpath
        // and fails on the missing POM. Debug builds never run lint, which is
        // why only `flutter build apk --release` broke. Excluding it from the
        // lint configurations alone changes nothing about what ships.
        configurations.matching { it.name.contains("Lint") }.configureEach {
            exclude(group = "com.google.android.gms", module = "play-services-tapandpay")
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
