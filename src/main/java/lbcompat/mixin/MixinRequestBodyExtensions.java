package lbcompat.mixin;

import okio.Buffer;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Pseudo;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Redirect;

/**
 * Copies the buffer a json body is written from, through a method every okio declares.
 * {@code Buffer.copy} arrived in okio 2.0, while {@code clone} exists in both.
 *
 * <p>The body is written on the call's own thread, so without this a request carrying one fails
 * with a {@link NoSuchMethodError} partway through rather than at load.
 */
@Pseudo
@Mixin(targets = "net.ccbluex.liquidbounce.api.core.RequestBodyExtensionsKt$asRequestBody$1",
       remap = false)
public abstract class MixinRequestBodyExtensions {

    @Redirect(
        method = "writeTo(Lokio/BufferedSink;)V",
        at = @At(value = "INVOKE", target = "Lokio/Buffer;copy()Lokio/Buffer;"),
        require = 0
    )
    private Buffer lbcompat$copyBuffer(Buffer buffer) {
        return buffer.clone();
    }
}
