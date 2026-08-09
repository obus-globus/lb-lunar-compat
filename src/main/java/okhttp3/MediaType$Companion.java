package okhttp3;

/** The companion okhttp declares from 4.0 on, for hosts that bundle an older release. */
public final class MediaType\u0024Companion {

    public MediaType get(String value) {
        return MediaType.get(value);
    }

    public MediaType parse(String value) {
        return MediaType.parse(value);
    }

    public MediaType toMediaType(String value) {
        return MediaType.get(value);
    }

    public MediaType toMediaTypeOrNull(String value) {
        return MediaType.parse(value);
    }
}
