package okhttp3;

/**
 * The companion okhttp declares from 4.0 on, for hosts that bundle an older release.
 *
 * <p>Callers compiled against a newer okhttp read {@code Headers.Companion} and invoke members on
 * it. A pre-4.0 okhttp has neither, so this supplies the type and {@code MixinHeaders} supplies the
 * field. Each member forwards to the static factory that release does declare.
 */
public final class Headers\u0024Companion {

    public Headers of(String... namesAndValues) {
        return Headers.of(namesAndValues);
    }

    public Headers of(java.util.Map<String, String> headers) {
        return Headers.of(headers);
    }

    public Headers headersOf(String... namesAndValues) {
        return Headers.of(namesAndValues);
    }
}
