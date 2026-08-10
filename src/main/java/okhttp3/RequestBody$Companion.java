package okhttp3;

import java.io.File;

/** The companion okhttp declares from 4.0 on, for hosts that bundle an older release. */
public final class RequestBody$Companion {

    public RequestBody create(String content, MediaType contentType) {
        return RequestBody.create(contentType, content);
    }

    public RequestBody create(byte[] content, MediaType contentType) {
        return RequestBody.create(contentType, content);
    }

    public RequestBody create(File file, MediaType contentType) {
        return RequestBody.create(contentType, file);
    }

    /** The default argument bridge kotlin emits for {@code create(content, type)}. */
    public static RequestBody create$default(RequestBody$Companion self, String content,
                                             MediaType contentType, int mask, Object marker) {
        return RequestBody.create((mask & 1) != 0 ? null : contentType, content);
    }
}
