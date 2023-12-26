import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework


val gradleVersion = "8.1.1"
val sqlDelightVersion = "2.0.1"
val ktorVersion = "2.3.6"
val coroutinesVersion = "1.7.3"
val dataTimeVersion = "0.4.1"
val immutablesVersion = "0.3.6"
val loggingVersion = "6.0.1"

plugins {
    kotlin("plugin.serialization") version "1.9.21"
    kotlin("multiplatform") version "1.9.21"
    id("org.openapi.generator") version "6.3.0"
    id("app.cash.sqldelight") version "2.0.1"
    id("com.google.devtools.ksp") version "1.9.21-1.0.15"
    id("com.rickclephas.kmp.nativecoroutines") version "1.0.0-ALPHA-22"
}

repositories {
    mavenCentral()
}

val generatedSourcesPath = "$buildDir/generated"
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

sqldelight {
    databases {
        create("DiagnoseStorage") {
            packageName.set("com.sourcepoint.diagnose.storage")
        }
    }
}

kotlin {
    applyDefaultHierarchyTemplate()
    macosArm64 {
        binaries {
            executable("hello")
        }
    }
    val libName = "DiagnoseSdk"
    val xcf = XCFramework(libName)
    val iosTargets = listOf(iosArm64(), iosSimulatorArm64())
    iosTargets.forEach {
        it.binaries.framework(libName) {
            xcf.add(this)
        }
    }

    sourceSets {
        all {
            languageSettings.optIn("kotlin.experimental.ExperimentalObjCName")
        }
        val commonMain by getting {
            dependencies {
                implementation("org.jetbrains.kotlinx:kotlinx-datetime:$dataTimeVersion")
                implementation("org.jetbrains.kotlinx:kotlinx-collections-immutable:$immutablesVersion")
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:$coroutinesVersion")
                implementation("io.ktor:ktor-client-core:$ktorVersion")
                implementation("io.ktor:ktor-client-content-negotiation:$ktorVersion")
                implementation("io.ktor:ktor-serialization-kotlinx-json:$ktorVersion")
                implementation("app.cash.sqldelight:primitive-adapters:$sqlDelightVersion")
                implementation("io.github.oshai:kotlin-logging:$loggingVersion")
            }
        }
        commonMain.kotlin.srcDir("$generatedSourcesPath/src/main/kotlin")
        commonTest.dependencies {
            implementation(kotlin("test"))
            implementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:$coroutinesVersion")
        }
        nativeMain.dependencies {
            implementation("app.cash.sqldelight:native-driver:$sqlDelightVersion")
        }
        macosMain.dependencies {
            implementation("io.ktor:ktor-client-darwin:$ktorVersion")
        }
        iosMain.dependencies {
            implementation("io.ktor:ktor-client-darwin:$ktorVersion")
        }
    }
}

tasks.withType<Wrapper> {
    gradleVersion = gradleVersion
    distributionType = Wrapper.DistributionType.BIN
}

tasks.withType<KotlinCompile>().configureEach { dependsOn("openApiGenerate") }
