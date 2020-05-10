package net.bjoernpetersen.lsass.jks;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Base64;
import java.util.Map;

@SuppressWarnings("unused")
public class Main implements RequestHandler<Map<String, String>, Map<String, String>> {
    @Override
    public Map<String, String> handleRequest(Map<String, String> input, Context context) {
        var p12 = input.get("p12");
        var password = input.get("pass");
        var decoded = Base64.getDecoder().decode(p12.getBytes(StandardCharsets.US_ASCII));
        var requestId = context.getAwsRequestId();
        var p12Path = Paths.get("/tmp", requestId + ".p12");
        try {
            Files.write(p12Path, decoded);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }

        var jksPath = Paths.get("/tmp", requestId + ".jks");
        convertKey(p12Path, jksPath, password);

        try {
            var jksBytes = Files.readAllBytes(jksPath);
            return encodeResult(jksBytes);
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
