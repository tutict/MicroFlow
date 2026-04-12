package com.microflow.auth.infrastructure.security;

import com.microflow.common.error.RateLimitExceededException;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class LoginAttemptRateLimiter {

    private final Clock clock;
    private final Duration window;
    private final int maxAttempts;
    private final Map<String, AttemptWindow> attempts = new ConcurrentHashMap<>();

    public LoginAttemptRateLimiter(
            Clock clock,
            @Value("${microflow.auth.login.window:PT5M}") Duration window,
            @Value("${microflow.auth.login.max-attempts:5}") int maxAttempts
    ) {
        this.clock = clock;
        this.window = window;
        this.maxAttempts = Math.max(1, maxAttempts);
    }

    public void checkAllowed(String email, String remoteAddress) {
        var now = Instant.now(clock);
        evictExpired(now);
        var attemptWindow = attempts.get(key(email, remoteAddress));
        if (attemptWindow != null && attemptWindow.failures() >= maxAttempts && !attemptWindow.expiresAt().isBefore(now)) {
            throw new RateLimitExceededException("Too many login attempts. Try again later.");
        }
    }

    public void recordFailure(String email, String remoteAddress) {
        var now = Instant.now(clock);
        attempts.compute(key(email, remoteAddress), (key, existing) -> {
            if (existing == null || existing.expiresAt().isBefore(now)) {
                return new AttemptWindow(1, now.plus(window));
            }
            return new AttemptWindow(existing.failures() + 1, existing.expiresAt());
        });
    }

    public void recordSuccess(String email, String remoteAddress) {
        attempts.remove(key(email, remoteAddress));
    }

    private void evictExpired(Instant now) {
        attempts.entrySet().removeIf(entry -> entry.getValue().expiresAt().isBefore(now));
    }

    private String key(String email, String remoteAddress) {
        var normalizedEmail = email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
        var normalizedAddress = remoteAddress == null ? "unknown" : remoteAddress.trim();
        return normalizedEmail + "|" + normalizedAddress;
    }

    private record AttemptWindow(
            int failures,
            Instant expiresAt
    ) {
    }
}
