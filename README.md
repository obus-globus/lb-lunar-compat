# LiquidBounce Lunar okhttp compat

[![build](https://github.com/obus-globus/lb-lunar-compat/actions/workflows/build.yml/badge.svg)](https://github.com/obus-globus/lb-lunar-compat/actions/workflows/build.yml)
[![okhttp compatibility](https://github.com/obus-globus/lb-lunar-compat/actions/workflows/okhttp-compat.yml/badge.svg)](https://github.com/obus-globus/lb-lunar-compat/actions/workflows/okhttp-compat.yml)
[![lunar boot, with the mod](https://github.com/obus-globus/lb-lunar-compat/actions/workflows/lunar-boot-with-mod.yml/badge.svg)](https://github.com/obus-globus/lb-lunar-compat/actions/workflows/lunar-boot-with-mod.yml)
[![release](https://img.shields.io/github/v/release/obus-globus/lb-lunar-compat?label=release)](https://github.com/obus-globus/lb-lunar-compat/releases/latest)
[![this mod](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fobus-globus%2Flb-lunar-compat%2Fmaster%2Fbadge%2Funaided.json)](https://github.com/obus-globus/lb-lunar-compat/actions/workflows/okhttp-compat-unaided.yml)

The last badge is the one to read first. It says whether a current LiquidBounce still calls
anything Lunar's okhttp lacks, so `not needed` means the mod has nothing left to do and you can
skip it. The unaided workflow behind it is expected to fail while the mod is still needed.

The boot check shows the mixins apply and nothing breaks at load. It cannot show the redirects
firing: the reads they cover sit behind the theme, which loads through MCEF and needs a GL
context no runner has, so a headless boot never reaches them. The static check is what covers
those, by resolving the reads against the okhttp Lunar ships rather than running them.

Lunar bundles okhttp 3.14.9, which predates okhttp's move to Kotlin in 4.0, and its copy wins
on Lunar's shared classloader. LiquidBounce is built against okhttp 5, so its calls read
companion fields that release does not declare, which throws where the read happens:

```
java.lang.NoSuchFieldError: Class okhttp3.Headers does not have member field 'okhttp3.Headers$Companion Companion'
	at Genesis//net.ccbluex.liquidbounce.integration.theme.Theme.<init>(Theme.kt:63)
```

That one was fixed upstream in CCBlueX/LiquidBounce#9082, and is kept here as the clearest
example of the shape. `covered-members.txt` is the current list. This mod supplies what is
missing, so a stock LiquidBounce runs unmodified. Drop it into the same mods folder.

## How it works

The companions cannot be restored by adding the fields back, because a mixin may only declare
private static fields. So this ships the companion types and redirects every read of them to an
instance of its own. Each companion forwards to the static factory that okhttp has declared
since 3.x and still declares today, so the same call works on either release.

One redirect is not a companion read: LiquidBounce copies a buffer with `Buffer.copy`, which
okio gained in 2.0, so it is sent through `clone` instead. That one runs while a request body is
being written rather than at load, so it surfaces as a failed request, not a crash on start.

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
Tested-LiquidBounce: 0.40.1 (nextgen 8576dbcfd)
Tested-Lunar: MC 26.2 master, okhttp 3.14.9
```

Tagging a commit `v0.2.0` builds it, checks the tag against the version in the jar, and
publishes the jar with those lines in the release notes.

## Scope

Written against LiquidBounce nextgen and Lunar's 26.2 build. It covers the okhttp calls
LiquidBounce makes today; a call it does not know about would still fail, and the class names
it targets are LiquidBounce's own, so a rename upstream needs a matching change here.
