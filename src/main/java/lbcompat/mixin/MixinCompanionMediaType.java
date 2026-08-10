package lbcompat.mixin;

import okhttp3.MediaType$Companion;
import org.objectweb.asm.Opcodes;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Pseudo;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Redirect;

/**
 * Serves the MediaType companion LiquidBounce reads, for a host bundling an okhttp older than 4.0.
 *
 * <p>The field cannot be put back, because a mixin may only declare private static fields, so
 * the read is redirected to a companion this mod ships. One class per companion because each
 * needs a single import: their simple names all collide otherwise.
 */
@Pseudo
@Mixin(targets = {
        "net.ccbluex.liquidbounce.integration.theme.Theme",
        "net.ccbluex.liquidbounce.api.core.HttpClient$MediaTypes",
        "net.ccbluex.liquidbounce.api.core.HttpClientKt",
        "net.ccbluex.liquidbounce.api.thirdparty.translator.providers.GoogleTranslateApiKt",
        "net.ccbluex.liquidbounce.api.services.marketplace.MarketplaceApi",
        "net.ccbluex.liquidbounce.features.module.modules.render.ModuleSkinChanger$Mode$File",
        "net.ccbluex.liquidbounce.authlib.utils.HttpUtils",
    }, remap = false)
public abstract class MixinCompanionMediaType {

    @Redirect(
        method = "*",
        at = @At(value = "FIELD", target = "Lokhttp3/MediaType;Companion:Lokhttp3/MediaType$Companion;", opcode = Opcodes.GETSTATIC),
        require = 0
    )
    private static MediaType$Companion lbcompat$mediaType() {
        return new MediaType$Companion();
    }
}
