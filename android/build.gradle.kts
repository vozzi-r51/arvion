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

subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            android.compileSdkVersion(36)

            // Align Java (17) and Kotlin (17) targets across all subprojects so plugins
            // don't fail with "Inconsistent JVM Target Compatibility".
            android.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
            project.plugins.withId("kotlin-android") {
                val kotlinAndroid = project.extensions.getByName("kotlin") as org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension
                kotlinAndroid.compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }

            // Some plugins (e.g. workmanager 0.5.2) configure Kotlin at evaluation
            // time, which races with afterEvaluate. For known-laggy plugins, force
            // the Kotlin compile tasks to JVM 17 after the project is fully
            // evaluated.
            if (project.name == "workmanager") {
                tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
                    // Use the new compilerOptions DSL (kotlinOptions is deprecated).
                    val kotlinTask = this
                    // compilerOptions is available on KotlinCompile from Kotlin
                    // Gradle Plugin 1.8.x; workmanager uses 1.8.10 which has it.
                    val compilerOptions = kotlinTask.compilerOptions
                    compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }

            // Fix for plugins that don't specify a namespace (required by newer AGP)
            if (android.namespace == null) {
                if (project.name == "blue_thermal_printer") {
                    android.namespace = "id.kakzaki.blue_thermal_printer"
                } else if (project.name == "flutter_local_notifications") {
                    android.namespace = "com.dexterous.flutterlocalnotifications"
                } else {
                    android.namespace = "com.bizmanager.plugins.${project.name.replace("-", "_")}"
                }
            }
        }
    }
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
