plugins {
    java
    id("com.github.ben-manes.versions") version "0.28.0"
}

dependencies {
    implementation("com.amazonaws:aws-lambda-java-core:1.2.0")
}

java {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
}

repositories {
    jcenter()
}
