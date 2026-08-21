package lbcompat.mixin;

import okhttp3.HttpUrl$Companion;
import org.objectweb.asm.Opcodes;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Pseudo;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Redirect;

/**
 * Serves the HttpUrl companion LiquidBounce reads, for a host bundling an okhttp older than 4.0.
 *
 * <p>The field cannot be put back, because a mixin may only declare private static fields, so
 * the read is redirected to a companion this mod ships. One class per companion because each
 * needs a single import: their simple names all collide otherwise.
 */
@Pseudo
@Mixin(targets = {
        "net.ccbluex.liquidbounce.api.core.HttpClient$MediaTypes",
        "net.ccbluex.liquidbounce.api.core.HttpClientKt",
        "net.ccbluex.liquidbounce.api.core.RequestBodyExtensionsKt$asRequestBody$1",
        "net.ccbluex.liquidbounce.api.services.marketplace.MarketplaceApi",
        "net.ccbluex.liquidbounce.api.thirdparty.translator.providers.GoogleTranslateApiKt",
        "net.ccbluex.liquidbounce.features.module.modules.render.ModuleSkinChanger$Mode$File",
    }, remap = false)
public abstract class MixinCompanionHttpUrl {

    @Redirect(
        method = "*",
        at = @At(value = "FIELD", target = "Lokhttp3/HttpUrl;Companion:Lokhttp3/HttpUrl$Companion;", opcode = Opcodes.GETSTATIC),
        require = 0
    )
    private static HttpUrl$Companion lbcompat$httpUrl() {
        return new HttpUrl$Companion();
    }
}
