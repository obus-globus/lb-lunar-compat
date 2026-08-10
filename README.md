# LiquidBounce Lunar okhttp compat

[![build](https://github.com/obus-globus/lb-lunar-compat/actions/workflows/build.yml/badge.svg)](https://github.com/obus-globus/lb-lunar-compat/actions/workflows/build.yml)
[![okhttp compatibility](https://github.com/obus-globus/lb-lunar-compat/actions/workflows/okhttp-compat.yml/badge.svg)](https://github.com/obus-globus/lb-lunar-compat/actions/workflows/okhttp-compat.yml)
[![lunar boot, with the mod](https://github.com/obus-globus/lb-lunar-compat/actions/workflows/lunar-boot-with-mod.yml/badge.svg)](https://github.com/obus-globus/lb-lunar-compat/actions/workflows/lunar-boot-with-mod.yml)
[![lunar boot, without the mod](https://github.com/obus-globus/lb-lunar-compat/actions/workflows/lunar-boot-unaided.yml/badge.svg)](https://github.com/obus-globus/lb-lunar-compat/actions/workflows/lunar-boot-unaided.yml)
[![release](https://img.shields.io/github/v/release/obus-globus/lb-lunar-compat?label=release)](https://github.com/obus-globus/lb-lunar-compat/releases/latest)

The last badge is inverted on purpose: it boots LiquidBounce without this mod and passes only
while that still fails, since the badge above it means nothing once there is nothing left to fix.

LiquidBounce does not start on Lunar Client. Lunar bundles okhttp 3.14.9, which predates
okhttp's move to Kotlin in 4.0, and its copy wins on Lunar's shared classloader. LiquidBounce
is built against okhttp 5, so its calls read companion fields that release does not declare:

```
java.lang.NoSuchFieldError: Class okhttp3.Headers does not have member field 'okhttp3.Headers$Companion Companion'
	at Genesis//net.ccbluex.liquidbounce.integration.theme.Theme.<init>(Theme.kt:63)
```

This mod supplies what is missing, so a stock LiquidBounce runs unmodified. Drop it into the
same mods folder.

## How it works

The companions cannot be restored by adding the fields back, because a mixin may only declare
private static fields. So this ships the companion types and redirects every read of them to an
instance of its own. Each companion forwards to the static factory that okhttp has declared
since 3.x and still declares today, so the same call works on either release.

The bundled `mc-authlib` is patched the same way. Its `HttpUtils` reads companions from a class
initialiser, which is why account login fails even once the client starts; its constants are
rebuilt from members every release declares, and the two other members it needs are redirected.

No okhttp class is overwritten. The redirects rewrite LiquidBounce's own call sites, so they
apply on any host, and the companions forward to factories a current okhttp declares too. That
keeps the calls correct there, but the mod is only tested against Lunar, and on a host carrying
its own companion classes which one wins is a load order question this does not settle. Install
it for Lunar.

## Building

```
./gradlew jar
```

The jar lands in `build/libs/`.

## Keeping up with LiquidBounce

`covered-members.txt` lists the okhttp and okio members LiquidBounce binds that Lunar's release
does not declare, and that this mod handles. A daily action builds LiquidBounce from nextgen,
fetches the okhttp Lunar serves that day, resolves every member the client and its bundled
libraries reference, and fails if one turns up outside that list, which means LiquidBounce
started calling something new and needs a matching redirect here.

It also checks that each member is redirected by a mixin that targets the class reading it,
that every mixin is registered in a config, and reports references made by okhttp classes the
client ships that the host lacks, which load unredirected.

Run it locally with:

```
./tools/fetch-lunar-okhttp.sh 26.2 lunar-okhttp.jar
python3 tools/check_okhttp_compat.py --client <liquidbounce.jar> \
    --host lunar-okhttp.jar --covered covered-members.txt
```

## What it was checked against

`tested-against.json` records the LiquidBounce build and the Lunar okhttp this was last
exercised on, and the build stamps them into the jar manifest, so a downloaded jar answers the
question on its own:

```
Tested-LiquidBounce: 0.39.1 (nextgen c86714198)
Tested-Lunar: MC 26.2 master, okhttp 3.14.9
```

Tagging a commit `v0.1.0` builds it, checks the tag against the version in the jar, and
publishes the jar with those lines in the release notes.

## Scope

Written against LiquidBounce nextgen and Lunar's 26.2 build. It covers the okhttp calls
LiquidBounce makes today; a call it does not know about would still fail, and the class names
it targets are LiquidBounce's own, so a rename upstream needs a matching change here.
