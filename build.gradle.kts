import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework

plugins {
    kotlin("plugin.serialization") version "1.9.21"
    kotlin("multiplatform") version "1.9.21"
    id("org.openapi.generator") version "6.3.0"
}

repositories { mavenCentral() }

val generatedSourcesPath = "$buildDir/generated" // layout.buildDirectory.dir("generated").toString()
val apiDescriptionFile = "$rootDir/src/resources/api.yaml"
val apiRootName = "com.sourcepoint.api.v1"

openApiGenerate {
    generatorName.set("kotlin")
    inputSpec.set(apiDescriptionFile)
    outputDir.set(generatedSourcesPath)
    apiPackage.set("$apiRootName.api")
    invokerPackage.set("$apiRootName.invoker")
    modelPackage.set("$apiRootName.model")
    configOptions.set(mapOf("library" to "multiplatform"))
}

kotlin {
    applyDefaultHierarchyTemplate()
    macosArm64 {
        binaries {
            executable("hello")
        }
    }
    val libName = "DiagnoseSdk2"
    val xcf = XCFramework(libName)
    val iosTargets = listOf(iosArm64(), iosSimulatorArm64())
    iosTargets.forEach {
        it.binaries.framework(libName) {
            xcf.add(this)
        }
    }

    sourceSets {
        val ktorVersion = "2.3.6"
        val coroutinesVersion = "1.7.3"
        val commonMain by getting {
            dependencies {
                implementation("org.jetbrains.kotlinx:kotlinx-datetime:0.4.1")
                implementation("org.jetbrains.kotlinx:kotlinx-collections-immutable:0.3.6")
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:$coroutinesVersion")
                implementation("io.ktor:ktor-client-core:$ktorVersion")
                implementation("io.ktor:ktor-client-content-negotiation:$ktorVersion")
                implementation("io.ktor:ktor-serialization-kotlinx-json:$ktorVersion")
            }
        }
        commonMain.kotlin.srcDir("$generatedSourcesPath/src/main/kotlin")
        val commonTest by getting {
            dependencies {
                implementation(kotlin("test"))
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:$coroutinesVersion")
            }
        }
//        val macosArmMain()
    }
}

tasks.withType<Wrapper> {
    gradleVersion = "8.1.1"
    distributionType = Wrapper.DistributionType.BIN
}

tasks.withType<KotlinCompile>().configureEach { dependsOn("openApiGenerate") }
