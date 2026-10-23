package lbcompat.mixin;

import okhttp3.Credentials;
import okhttp3.Response;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Pseudo;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Coerce;
import org.spongepowered.asm.mixin.injection.Redirect;

import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;

/**
 * Serves the default argument bridges the proxy support calls, which only okhttp's kotlin
 * releases declare. Each forwards to the overload taking every argument, which 3.x has too.
 */
@Pseudo
@Mixin(targets = {
        "net.ccbluex.liquidbounce.features.misc.proxy.Proxy",
        "net.ccbluex.liquidbounce.features.misc.proxy.OkHttpUrlConnection",
    }, remap = false)
public abstract class MixinProxyDefaults {

    /** Proxy authentication, sent once the proxy asks for it. The charset defaults to latin-1. */
    @Redirect(
        method = "*",
        at = @At(value = "INVOKE",
                 target = "Lokhttp3/Credentials;basic$default(Ljava/lang/String;Ljava/lang/String;"
                          + "Ljava/nio/charset/Charset;ILjava/lang/Object;)Ljava/lang/String;"),
        require = 0
    )
    private static String lbcompat$basic(String username, String password, Charset charset,
                                         int mask, @Coerce Object marker) {
        return Credentials.basic(username, password,
                (mask & 4) != 0 ? StandardCharsets.ISO_8859_1 : charset);
    }

    /** A header read through the proxied connection. The fallback value defaults to null. */
    @Redirect(
        method = "*",
        at = @At(value = "INVOKE",
                 target = "Lokhttp3/Response;header$default(Lokhttp3/Response;Ljava/lang/String;"
                          + "Ljava/lang/String;ILjava/lang/Object;)Ljava/lang/String;"),
        require = 0
    )
    private static String lbcompat$header(Response response, String name, String defaultValue,
                                          int mask, @Coerce Object marker) {
        return response.header(name, (mask & 2) != 0 ? null : defaultValue);
    }
}
