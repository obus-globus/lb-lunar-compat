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

version = "0.1.1"

// What the mod was last checked against, so a downloaded jar can say so itself.
val testedAgainst = groovy.json.JsonSlurper()
    .parse(file("tested-against.json")) as Map<String, Any>

tasks.jar {
    archiveBaseName = "lb-lunar-compat"
    manifest {
        @Suppress("UNCHECKED_CAST")
        val lb = testedAgainst["liquidbounce"] as Map<String, Any>
        @Suppress("UNCHECKED_CAST")
        val lunar = testedAgainst["lunar"] as Map<String, Any>
        attributes(
            "Implementation-Title" to "lb-lunar-compat",
            "Implementation-Version" to project.version,
            "Tested-LiquidBounce" to "${lb["version"]} (${lb["branch"]} ${lb["commit"]})",
            "Tested-Lunar" to "MC ${lunar["mc_version"]} ${lunar["branch"]}, okhttp ${lunar["okhttp"]}",
            "Tested-On" to testedAgainst["verified_on"].toString(),
        )
    }
}
