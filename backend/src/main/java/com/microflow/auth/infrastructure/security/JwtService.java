package com.microflow.auth.infrastructure.security;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
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
            var parts = token.split("\\.");
            if (parts.length != 3) {
                throw new IllegalArgumentException("Malformed JWT");
            }
            var expectedSignature = sign(parts[0] + "." + parts[1]);
            if (!expectedSignature.equals(parts[2])) {
                throw new IllegalArgumentException("Invalid JWT signature");
            }
            var payload = objectMapper.readValue(URL_DECODER.decode(parts[1]), MAP_TYPE);
            var exp = ((Number) payload.get("exp")).longValue();
            if (Instant.now(clock).getEpochSecond() >= exp) {
                throw new IllegalArgumentException("JWT expired");
            }
            return new JwtPrincipal(
                    (String) payload.get("sub"),
                    (String) payload.get("email"),
                    (String) payload.get("name")
            );
        } catch (Exception ex) {
            throw new IllegalArgumentException("Invalid JWT", ex);
        }
    }

    private String sign(String content) {
        try {
            var mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(signingKey, "HmacSHA256"));
            return URL_ENCODER.encodeToString(mac.doFinal(content.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to sign JWT", ex);
        }
    }
}

