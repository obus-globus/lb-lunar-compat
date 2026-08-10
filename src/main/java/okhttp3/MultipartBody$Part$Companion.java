package okhttp3;

/** The companion okhttp declares from 4.0 on, for hosts that bundle an older release. */
public final class MultipartBody$Part$Companion {

    public MultipartBody.Part createFormData(String name, String filename, RequestBody body) {
        return MultipartBody.Part.createFormData(name, filename, body);
    }

    public MultipartBody.Part createFormData(String name, String value) {
        return MultipartBody.Part.createFormData(name, value);
    }
}
