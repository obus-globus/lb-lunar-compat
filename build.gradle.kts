plugins { java }

repositories {
    mavenCentral()
    maven("https://maven.fabricmc.net/")
    maven("https://maven.ccbluex.net/releases")
}

dependencies {
    // The okhttp a host may bundle. Compiled against, never shipped: the shims forward to the
    // static factories this release declares and a newer one still carries.
    compileOnly("com.squareup.okhttp3:okhttp:3.14.9")
    compileOnly("net.fabricmc:sponge-mixin:0.17.3+mixin.0.8.7")
    // Transitively wants Mojang's authlib, which is not on a public repo; only its own classes
    // are referenced here.
    compileOnly("net.ccbluex:mc-authlib:1.7.1") { isTransitive = false }
    compileOnly("org.ow2.asm:asm:9.10.1")
}

java { toolchain { languageVersion = JavaLanguageVersion.of(21) } }

tasks.jar {
    archiveBaseName = "lb-lunar-compat"
    manifest { attributes("Implementation-Version" to project.version) }
}
