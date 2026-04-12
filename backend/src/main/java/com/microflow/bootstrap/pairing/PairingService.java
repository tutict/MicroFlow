package com.microflow.bootstrap.pairing;

import jakarta.annotation.PostConstruct;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicReference;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class PairingService {

    private static final Logger log = LoggerFactory.getLogger(PairingService.class);
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final char[] ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".toCharArray();

    private final Clock clock;
    private final Duration ttl;
    private final String instanceName;
    private final AtomicReference<PairingChallenge> currentChallenge = new AtomicReference<>();

    public PairingService(
            Clock clock,
            @Value("${microflow.bootstrap.pairing.ttl:PT10M}") Duration ttl,
            @Value("${microflow.bootstrap.instance-name:${spring.application.name}}") String instanceName
    ) {
        this.clock = clock;
        this.ttl = ttl;
        this.instanceName = instanceName;
    }

    @PostConstruct
    void initialize() {
        rotateChallenge();
        logCurrentChallenge();
    }

    public PairingChallenge currentChallenge() {
        var challenge = currentChallenge.get();
        if (challenge == null || challenge.expiresAt().isBefore(Instant.now(clock))) {
            challenge = rotateChallenge();
            logCurrentChallenge();
        }
        return challenge;
    }

    public PairingExchange redeem(String rawPairingCode) {
        var normalized = normalize(rawPairingCode);
        if (normalized == null) {
            throw new IllegalArgumentException("Pairing code is required");
        }
        var challenge = currentChallenge();
        if (!challenge.code().equals(normalized)) {
            throw new IllegalArgumentException("Invalid pairing code");
        }
        if (challenge.expiresAt().isBefore(Instant.now(clock))) {
            rotateChallenge();
            logCurrentChallenge();
            throw new IllegalArgumentException("Pairing code expired");
        }
        var exchange = new PairingExchange(instanceName, Instant.now(clock));
        rotateChallenge();
        logCurrentChallenge();
        return exchange;
    }

    public String instanceName() {
        return instanceName;
    }

    private PairingChallenge rotateChallenge() {
        var next = new PairingChallenge(generateCode(), Instant.now(clock).plus(ttl));
        currentChallenge.set(next);
        return next;
    }

    private void logCurrentChallenge() {
        var challenge = currentChallenge.get();
        if (challenge == null) {
            return;
        }
        log.info(
                "MicroFlow pairing code for instance '{}' is {} (expires at {})",
                instanceName,
                challenge.code(),
                challenge.expiresAt()
        );
    }

    private String generateCode() {
        return randomChunk(4) + "-" + randomChunk(4);
    }

    private String randomChunk(int size) {
        var buffer = new char[size];
        for (var index = 0; index < size; index++) {
            buffer[index] = ALPHABET[RANDOM.nextInt(ALPHABET.length)];
        }
        return new String(buffer);
    }

    private String normalize(String value) {
        if (value == null) {
            return null;
        }
        var normalized = value
                .trim()
                .replace(" ", "")
                .replace("-", "")
                .toUpperCase(Locale.ROOT);
        if (normalized.length() != 8) {
            return null;
        }
        return normalized.substring(0, 4) + "-" + normalized.substring(4);
    }
}
