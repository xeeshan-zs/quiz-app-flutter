allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Define global properties for plugins that require them
extra.apply {
    set("compileSdkVersion", 36)
    set("minSdkVersion", 23)
    set("targetSdkVersion", 36)
    set("ndkVersion", "27.0.12077973")
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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
