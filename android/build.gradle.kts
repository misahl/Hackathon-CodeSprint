buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // Mapbox SDK — required by mapbox_maps_flutter
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication {
                create<HttpHeaderAuthentication>("header")
            }
            credentials(HttpHeaderCredentials::class) {
                name = "Authorization"
                // The Mapbox secret token is read from ~/.gradle/gradle.properties
                // Set: MAPBOX_DOWNLOADS_TOKEN=sk.xxx
                value = "Bearer ${providers.gradleProperty("MAPBOX_DOWNLOADS_TOKEN").orElse("").get()}"
            }
        }
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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
