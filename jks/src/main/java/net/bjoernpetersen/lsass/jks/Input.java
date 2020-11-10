package net.bjoernpetersen.lsass.jks;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Map;

final class Input {
    private final String p12;
    private final String password;

    Input(Map<String, String> raw) {
        this.p12 = raw.get("p12");
        this.password = raw.get("pass");
    }

    byte[] decodeP12() {
        return Base64.getDecoder().decode(p12.getBytes(StandardCharsets.US_ASCII));
    }

    String getPassword() {
        return password;
    }
}
