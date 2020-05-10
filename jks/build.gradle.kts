plugins {
    java
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
