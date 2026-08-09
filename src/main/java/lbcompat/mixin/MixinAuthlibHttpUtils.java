package lbcompat.mixin;

import net.ccbluex.liquidbounce.authlib.utils.HttpUtils;
import okhttp3.Headers;
import okhttp3.MediaType;
import org.objectweb.asm.Opcodes;
import org.spongepowered.asm.mixin.Final;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Mutable;
import org.spongepowered.asm.mixin.Pseudo;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.gen.Invoker;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.Redirect;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/**
 * Builds the http constants LiquidBounce's bundled authlib holds, without okhttp's companions.
 *
 * <p>The class initialiser reads companions a pre-4.0 okhttp does not declare, so it throws before
 * authlib serves a request and account login fails with it. Assign the same values from members
 * every release declares, and redirect the empty headers the argument defaults read.
 */
@Pseudo
@Mixin(targets = "net.ccbluex.liquidbounce.authlib.utils.HttpUtils", remap = false)
public abstract class MixinAuthlibHttpUtils {

    @Shadow @Final @Mutable
    private static HttpUtils INSTANCE;

    @Shadow @Final @Mutable
    private static Headers HEADERS_JSON;

    @Shadow @Final @Mutable
    private static Headers HEADERS_FORM;

    @Shadow @Final @Mutable
    private static Headers HEADERS_JSON_RESPONSE;

    @Shadow @Final @Mutable
    private static MediaType MEDIA_TYPE_JSON;

    @Invoker("<init>")
    private static HttpUtils lbcompat$create() {
        throw new AssertionError();
    }

    @Inject(method = "<clinit>", at = @At("HEAD"), cancellable = true, require = 0)
    private static void lbcompat$init(CallbackInfo ci) {
        INSTANCE = lbcompat$create();
        HEADERS_JSON = new Headers.Builder().add("Content-Type", "application/json").build();
        HEADERS_FORM = new Headers.Builder()
            .add("Content-Type", "application/x-www-form-urlencoded").build();
        HEADERS_JSON_RESPONSE = new Headers.Builder().add("Accept", "application/json").build();
        MEDIA_TYPE_JSON = MediaType.get("application/json; charset=utf-8");
        ci.cancel();
    }

    @Redirect(
        method = "*",
        at = @At(value = "FIELD", target = "Lokhttp3/Headers;EMPTY:Lokhttp3/Headers;",
                 opcode = Opcodes.GETSTATIC),
        require = 0
    )
    private static Headers lbcompat$emptyHeaders() {
        return new Headers.Builder().build();
    }
}
