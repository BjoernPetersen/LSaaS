package net.bjoernpetersen.lsass.jks;

import com.amazonaws.services.lambda.runtime.Context;

import java.nio.file.Path;
import java.nio.file.Paths;

final class Storage {
    private static final String TMP_DIR = "/tmp";
    private static final String EXTENSION_PKCS = ".p12";
    private static final String EXTENSION_JKS = ".jks";

    private final String requestId;
    private final Path dir;

    Storage(Context context) {
        this(context.getAwsRequestId());
    }

    Storage(String requestId) {
        this.requestId = requestId;
        this.dir = Paths.get(TMP_DIR);
    }

    Path getP12Path() {
        return dir.resolve(requestId + EXTENSION_PKCS);
    }

    Path getJksPath() {
        return dir.resolve(requestId + EXTENSION_JKS);
    }
}
