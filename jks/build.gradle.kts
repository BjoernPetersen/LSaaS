plugins {
    java
    id("com.github.ben-manes.versions") version "0.44.0"
}

dependencies {
    implementation("com.amazonaws:aws-lambda-java-core:1.2.2")
    implementation("io.sentry:sentry:6.13.0")
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(11))
    }
}

repositories {
    mavenCentral()
}

tasks {
    create("awsZip", Zip::class) {
        from(compileJava, processResources)
        into("lib") {
            from(configurations.runtimeClasspath)
        }
    }
}
