package com.microflow.auth.infrastructure.security;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class JwtService {

    private static final Base64.Encoder URL_ENCODER = Base64.getUrlEncoder().withoutPadding();
    private static final Base64.Decoder URL_DECODER = Base64.getUrlDecoder();
    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() { };

    private final ObjectMapper objectMapper;
    private final Clock clock;
    private final byte[] signingKey;
    private final long ttlSeconds;

    public JwtService(
            ObjectMapper objectMapper,
            Clock clock,
            @Value("${microflow.jwt.secret}") String secret,
            @Value("${microflow.jwt.ttl-seconds:28800}") long ttlSeconds
    ) {
        this.objectMapper = objectMapper;
        this.clock = clock;
        this.signingKey = secret.getBytes(StandardCharsets.UTF_8);
        this.ttlSeconds = ttlSeconds;
    }

    public String issueToken(String userId, String email, String displayName) {
        try {
            var header = URL_ENCODER.encodeToString(objectMapper.writeValueAsBytes(Map.of(
                    "alg", "HS256",
                    "typ", "JWT"
            )));
            var issuedAt = Instant.now(clock).getEpochSecond();
            var payload = URL_ENCODER.encodeToString(objectMapper.writeValueAsBytes(Map.of(
                    "sub", userId,
                    "email", email,
                    "name", displayName,
                    "iat", issuedAt,
                    "exp", issuedAt + ttlSeconds
            )));
            var signature = sign(header + "." + payload);
            return header + "." + payload + "." + signature;
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to issue JWT", ex);
        }
    }

    public JwtPrincipal verify(String token) {
        try {
            var parts = token.split("\\.", -1);
            if (parts.length != 3 || parts[0].isBlank() || parts[1].isBlank() || parts[2].isBlank()) {
                throw new IllegalArgumentException("Malformed JWT");
            }
            validateHeader(parts[0]);
            validateSignature(parts);
            var payload = objectMapper.readValue(URL_DECODER.decode(parts[1]), MAP_TYPE);
            var subject = requiredString(payload, "sub");
            var email = requiredString(payload, "email");
            var displayName = requiredString(payload, "name");
            requiredLong(payload, "iat");
            var exp = requiredLong(payload, "exp");
            if (Instant.now(clock).getEpochSecond() >= exp) {
                throw new IllegalArgumentException("JWT expired");
            }
            return new JwtPrincipal(subject, email, displayName);
        } catch (Exception ex) {
            throw new IllegalArgumentException("Invalid JWT", ex);
        }
    }

    private void validateHeader(String encodedHeader) throws Exception {
        var header = objectMapper.readValue(URL_DECODER.decode(encodedHeader), MAP_TYPE);
        if (!"HS256".equals(header.get("alg")) || !"JWT".equals(header.get("typ"))) {
            throw new IllegalArgumentException("Unsupported JWT header");
        }
    }

    private void validateSignature(String[] parts) {
        var expectedSignature = signBytes(parts[0] + "." + parts[1]);
        var actualSignature = URL_DECODER.decode(parts[2]);
        if (!MessageDigest.isEqual(expectedSignature, actualSignature)) {
            throw new IllegalArgumentException("Invalid JWT signature");
        }
    }

    private String requiredString(Map<String, Object> payload, String key) {
        var value = payload.get(key);
        if (value instanceof String text && !text.isBlank()) {
            return text;
        }
        throw new IllegalArgumentException("Missing JWT claim: " + key);
    }

    private long requiredLong(Map<String, Object> payload, String key) {
        var value = payload.get(key);
        if (value instanceof Number number) {
            return number.longValue();
        }
        throw new IllegalArgumentException("Missing JWT claim: " + key);
    }

    private String sign(String content) {
        return URL_ENCODER.encodeToString(signBytes(content));
    }

    private byte[] signBytes(String content) {
        try {
            var mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(signingKey, "HmacSHA256"));
            return mac.doFinal(content.getBytes(StandardCharsets.UTF_8));
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to sign JWT", ex);
        }
    }
}

