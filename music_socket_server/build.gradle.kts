plugins {
    application
    java
}

group = "org.example"
version = "1.0.0"

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17)) // یا 21 اگه JDK 21 داری
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("com.google.code.gson:gson:2.10.1")
    testImplementation(platform("org.junit:junit-bom:5.11.0"))
    testImplementation("org.junit.jupiter:junit-jupiter")
}

application {
    // چون کلاس main در default package است:
    mainClass.set("SocketMusicServer")
}

tasks.test {
    useJUnitPlatform()
}
