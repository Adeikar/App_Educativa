allprojects {
    repositories {
        google()
        mavenCentral()
    }
}


val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val subBuild = newBuildDir.dir(project.name)
    layout.buildDirectory.value(subBuild)
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
