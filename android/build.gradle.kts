allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    // 1. Primero registramos la regla de inyección del namespace
    afterEvaluate {
        val androidPlugin = extensions.findByName("android")
        if (androidPlugin != null) {
            try {
                val namespaceProp = androidPlugin.javaClass.getMethod("getNamespace").invoke(androidPlugin)
                if (namespaceProp == null) {
                    androidPlugin.javaClass.getMethod("setNamespace", String::class.java).invoke(androidPlugin, project.group.toString())
                }
            } catch (e: Exception) {
                // Ignorar silenciosamente si no aplica
            }
        }
    }

    // 2. Después forzamos la evaluación para que la regla anterior tenga efecto
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}