package lbcompat.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Unique;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/**
 * Initialises ModuleItemChams before LiquidBounce's lightmap hook reads its nested Lightmap.
 *
 * <p>The two initialise each other: Lightmap's constructor reads ModuleItemChams, whose
 * initialiser passes Lightmap on as a value group. Started from ModuleItemChams, as module
 * registration does, that works. Started from Lightmap, the outer one finds it still null and
 * throws. LiquidBounce's hook on getTextureView starts from Lightmap, and Lunar asks for the
 * lightmap during its own startup, before LiquidBounce has registered its modules, so on Lunar
 * the game dies in init. Loading the outer class first here, at the head of the same method,
 * restores the order registration would have used.
 */
@Mixin(targets = "net.minecraft.client.renderer.Lightmap", remap = false)
public abstract class MixinItemChamsInitOrder {

    @Unique
    private static final String LBCOMPAT$ITEM_CHAMS =
        "net.ccbluex.liquidbounce.features.module.modules.render.ModuleItemChams";

    @Unique
    private static volatile boolean lbcompat$itemChamsReady;

    @Inject(method = "getTextureView", at = @At("HEAD"), require = 0)
    private void lbcompat$initItemChams(CallbackInfoReturnable<Object> cir) {
        if (lbcompat$itemChamsReady) {
            return;
        }
        lbcompat$itemChamsReady = true;
        try {
            Class.forName(LBCOMPAT$ITEM_CHAMS, true, getClass().getClassLoader());
        } catch (ClassNotFoundException ignored) {
            // A LiquidBounce without the module has nothing to put in order.
        }
    }
}
