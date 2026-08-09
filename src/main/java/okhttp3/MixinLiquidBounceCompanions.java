package okhttp3;

import org.objectweb.asm.Opcodes;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Pseudo;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Redirect;

/**
 * Serves the okhttp companions LiquidBounce reads, for hosts that bundle an okhttp older than 4.0.
 *
 * <p>okhttp moved its factories onto Kotlin companions in 4.0, so LiquidBounce reads a companion
 * field a pre-4.0 release does not declare. The field cannot be added, because a mixin may only
 * declare private static fields, so every read is redirected to a companion this mod ships.
 */
@Pseudo
@Mixin(
    targets = {
        "net.ccbluex.liquidbounce.integration.theme.Theme",
        "net.ccbluex.liquidbounce.api.core.HttpClient$MediaTypes",
        "net.ccbluex.liquidbounce.api.core.HttpClientKt",
        "net.ccbluex.liquidbounce.api.thirdparty.translator.providers.GoogleTranslateApiKt",
        "net.ccbluex.liquidbounce.api.services.marketplace.MarketplaceApi",
        "net.ccbluex.liquidbounce.features.module.modules.render.ModuleSkinChanger$Mode$File",
    },
    remap = false
)
public abstract class MixinLiquidBounceCompanions {

    @Redirect(
        method = "*",
        at = @At(value = "FIELD", target = "Lokhttp3/Headers;Companion:Lokhttp3/Headers$Companion;",
                 opcode = Opcodes.GETSTATIC),
        require = 0
    )
    private static Headers\u0024Companion lbcompat$headers() {
        return new Headers\u0024Companion();
    }

    @Redirect(
        method = "*",
        at = @At(value = "FIELD", target = "Lokhttp3/MediaType;Companion:Lokhttp3/MediaType$Companion;",
                 opcode = Opcodes.GETSTATIC),
        require = 0
    )
    private static MediaType\u0024Companion lbcompat$mediaType() {
        return new MediaType\u0024Companion();
    }

    @Redirect(
        method = "*",
        at = @At(value = "FIELD", target = "Lokhttp3/HttpUrl;Companion:Lokhttp3/HttpUrl$Companion;",
                 opcode = Opcodes.GETSTATIC),
        require = 0
    )
    private static HttpUrl\u0024Companion lbcompat$httpUrl() {
        return new HttpUrl\u0024Companion();
    }

    @Redirect(
        method = "*",
        at = @At(value = "FIELD", target = "Lokhttp3/RequestBody;Companion:Lokhttp3/RequestBody$Companion;",
                 opcode = Opcodes.GETSTATIC),
        require = 0
    )
    private static RequestBody\u0024Companion lbcompat$requestBody() {
        return new RequestBody\u0024Companion();
    }

    @Redirect(
        method = "*",
        at = @At(value = "FIELD",
                 target = "Lokhttp3/MultipartBody$Part;Companion:Lokhttp3/MultipartBody$Part$Companion;",
                 opcode = Opcodes.GETSTATIC),
        require = 0
    )
    private static MultipartBody\u0024Part\u0024Companion lbcompat$multipartPart() {
        return new MultipartBody\u0024Part\u0024Companion();
    }
}
