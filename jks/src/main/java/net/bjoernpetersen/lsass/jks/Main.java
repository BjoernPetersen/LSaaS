package net.bjoernpetersen.lsass.jks;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import io.sentry.Sentry;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Base64;
import java.util.Map;

@SuppressWarnings("unused")
public final class Main implements RequestHandler<Map<String, String>, Map<String, String>> {
    private static final String TMP_DIR = "/tmp";
    private static final String EXTENSION_PKCS = ".p12";
    private static final String EXTENSION_JKS = ".jks";

    @Override
    public Map<String, String> handleRequest(Map<String, String> rawInput, Context context) {
        setupSentry();

        var input = new Input(rawInput);
        var storage = new Storage(context);

        var p12Path = storage.getP12Path();
        writeToFile(p12Path, input.decodeP12());

        var jksPath = storage.getJksPath();
        convertKey(p12Path, jksPath, input.getPassword());

        var resultData = readFileBytes(jksPath);
        return encodeResult(resultData);
    }

    private void setupSentry() {
        Sentry.init(options -> options.setDsn(System.getenv("SENTRY_DSN")));
    }

    private void writeToFile(Path path, byte[] data) {
        try {
            Files.write(path, data);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    private byte[] readFileBytes(Path path) {
        try {
            return Files.readAllBytes(path);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    private Map<String, String> encodeResult(byte[] jksBytes) {
        var encodedBytes = Base64.getEncoder().encode(jksBytes);
        var encoded = new String(encodedBytes, StandardCharsets.US_ASCII);
        return Map.of("result", encoded);
    }

    private void convertKey(Path p12Path, Path jksPath, String pass) {
        // The whole reason we're using Java is that we can assume the keytool is available in the Java Lambda Runtime
        try {
            new ProcessBuilder(
                "keytool",
                "-importkeystore",
                "-noprompt",
                "-srckeystore", p12Path.toString(),
                "-srcstorepass", pass,
                "-srcstoretype", "pkcs12",
                "-destkeystore", jksPath.toString(),
                "-deststorepass", pass
            ).inheritIO().start().waitFor();
        } catch (IOException | InterruptedException e) {
            e.printStackTrace();
            throw new RuntimeException(e);
        }
    }
}
