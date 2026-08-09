package okhttp3;

import java.io.File;

/** The companion okhttp declares from 4.0 on, for hosts that bundle an older release. */
public final class RequestBody\u0024Companion {

    public RequestBody create(String content, MediaType contentType) {
        return RequestBody.create(contentType, content);
    }

    public RequestBody create(byte[] content, MediaType contentType) {
        return RequestBody.create(contentType, content);
    }

    public RequestBody create(File file, MediaType contentType) {
        return RequestBody.create(contentType, file);
    }

    public RequestBody toRequestBody(String content, MediaType contentType) {
        return RequestBody.create(contentType, content);
    }

    public RequestBody asRequestBody(File file, MediaType contentType) {
        return RequestBody.create(contentType, file);
    }
}
