package lbcompat.mixin;

import okhttp3.MultipartBody;
import okio.Okio;
import okio.Sink;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Pseudo;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Coerce;
import org.spongepowered.asm.mixin.injection.Redirect;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;

/**
 * Serves the two members kotlin's default arguments produce that an older okhttp and okio do
 * not declare.
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
public abstract class MixinKotlinDefaults {

    /** okio only grew a two argument sink after the release a host may bundle. */
    @Redirect(
        method = "*",
        at = @At(value = "INVOKE",
                 target = "Lokio/Okio;sink$default(Ljava/io/File;ZILjava/lang/Object;)Lokio/Sink;"),
        require = 0
    )
    private static Sink lbcompat$sink(File file, boolean append, int flags, @Coerce Object marker)
            throws FileNotFoundException {
        return Okio.sink(new FileOutputStream(file, append));
    }

    /** The boundary defaulting constructor, which the older release does not declare. */
    @Redirect(
        method = "*",
        at = @At(value = "NEW", target = "(Ljava/lang/String;ILkotlin/jvm/internal/DefaultConstructorMarker;)"
                 + "Lokhttp3/MultipartBody$Builder;"),
        require = 0
    )
    private static MultipartBody.Builder lbcompat$multipartBuilder(
            String boundary, int flags, @Coerce Object marker) {
        return boundary == null ? new MultipartBody.Builder() : new MultipartBody.Builder(boundary);
    }
}
