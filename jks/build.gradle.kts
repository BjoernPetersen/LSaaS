plugins {
    java
    id("com.github.ben-manes.versions") version "0.36.0"
}

dependencies {
    implementation("com.amazonaws:aws-lambda-java-core:1.2.1")
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(11))
    }
}

repositories {
    jcenter()
}
