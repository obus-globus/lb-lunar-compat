package okhttp3;

/** The companion okhttp declares from 4.0 on, for hosts that bundle an older release. */
public final class HttpUrl\u0024Companion {

    public HttpUrl get(String value) {
        return HttpUrl.get(value);
    }

    public HttpUrl parse(String value) {
        return HttpUrl.parse(value);
    }

    public HttpUrl toHttpUrl(String value) {
        return HttpUrl.get(value);
    }

    public HttpUrl toHttpUrlOrNull(String value) {
        return HttpUrl.parse(value);
    }
}
