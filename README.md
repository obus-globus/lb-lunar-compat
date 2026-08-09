# LiquidBounce Lunar okhttp compat

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

Nothing is shipped that overwrites an okhttp class. On a host with a current okhttp none of the
redirects match, and every injector is optional, so the mod does nothing rather than failing.

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

Run it locally with:

```
./tools/fetch-lunar-okhttp.sh 26.2 lunar-okhttp.jar
python3 tools/check_okhttp_compat.py --client <liquidbounce.jar> \
    --host lunar-okhttp.jar --covered covered-members.txt
```

## Scope

Written against LiquidBounce nextgen and Lunar's 26.2 build. It covers the okhttp calls
LiquidBounce makes today; a call it does not know about would still fail, and the class names
it targets are LiquidBounce's own, so a rename upstream needs a matching change here.
