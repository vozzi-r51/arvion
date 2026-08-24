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
            
            // Fix for plugins that don't specify a namespace (required by newer AGP)
            if (android.namespace == null) {
                if (project.name == "blue_thermal_printer") {
                    android.namespace = "id.kakzaki.blue_thermal_printer"
                } else if (project.name == "flutter_local_notifications") {
                    android.namespace = "com.dexterous.flutterlocalnotifications"
                } else {
                    android.namespace = "com.example.${project.name.replace("-", "_")}"
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
