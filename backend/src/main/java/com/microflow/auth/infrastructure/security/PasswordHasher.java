package com.microflow.auth.infrastructure.security;

import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.security.spec.KeySpec;
import java.util.Base64;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import org.springframework.stereotype.Component;

@Component
public class PasswordHasher {

    private static final int ITERATIONS = 65_536;
    private static final int KEY_LENGTH = 256;
    private static final SecureRandom RANDOM = new SecureRandom();

    public String hash(String rawPassword) {
        var salt = new byte[16];
        RANDOM.nextBytes(salt);
        return encode(rawPassword, salt);
    }

    public boolean matches(String rawPassword, String storedHash) {
        var parts = storedHash.split(":");
        if (parts.length != 3) {
            return false;
        }
        var iterations = Integer.parseInt(parts[0]);
        var salt = Base64.getDecoder().decode(parts[1]);
        var candidate = encode(rawPassword, salt, iterations);
        return slowEquals(candidate.getBytes(StandardCharsets.UTF_8), storedHash.getBytes(StandardCharsets.UTF_8));
    }

    private String encode(String rawPassword, byte[] salt) {
        return encode(rawPassword, salt, ITERATIONS);
    }

    private String encode(String rawPassword, byte[] salt, int iterations) {
        try {
            KeySpec spec = new PBEKeySpec(rawPassword.toCharArray(), salt, iterations, KEY_LENGTH);
            var secretKeyFactory = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256");
            var hash = secretKeyFactory.generateSecret(spec).getEncoded();
            return iterations + ":" + Base64.getEncoder().encodeToString(salt) + ":" + Base64.getEncoder().encodeToString(hash);
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to hash password", ex);
        }
    }

    private boolean slowEquals(byte[] left, byte[] right) {
        int diff = left.length ^ right.length;
        for (int i = 0; i < Math.min(left.length, right.length); i++) {
            diff |= left[i] ^ right[i];
        }
        return diff == 0;
    }
}

