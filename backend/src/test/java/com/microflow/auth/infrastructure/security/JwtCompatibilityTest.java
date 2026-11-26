package com.microflow.auth.infrastructure.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

class JwtCompatibilityTest {
    private static final String SECRET = "legacy-jackson-migration-test-key-2026";
    // Produced and verified by the pre-migration JwtService with Jackson 2.21.8.
    private static final String LEGACY_TOKEN =
            "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9."
            + "eyJuYW1lIjoi5pen5a6i5oi356uvIiwiaWF0IjoxNzk1NjUxMjAwLCJzdWIiOiJ1c3JfbGVnYWN5IiwiZW1haWwiOiJsZWdhY3lAZXhhbXBsZS5jb20iLCJleHAiOjE3OTU2NTQ4MDB9."
            + "XDB1WCTT-eNe3XqDHLXmy2zZ9sgDHn2BcsrJCr8TPxA";

    @Test
    void jacksonTwoTokensRetainTheirIdentityAfterUpgrade() {
        var principal = serviceAt("2026-11-26T00:30:00Z").verify(LEGACY_TOKEN);

        assertThat(principal.userId()).isEqualTo("usr_legacy");
        assertThat(principal.email()).isEqualTo("legacy@example.com");
        assertThat(principal.displayName()).isEqualTo("旧客户端");
    }

    @Test
    void legacyTokensStillExpireAtTheirOriginalBoundary() {
        assertThatThrownBy(() -> serviceAt("2026-11-26T01:00:00Z").verify(LEGACY_TOKEN))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("Invalid JWT")
                .hasRootCauseMessage("JWT expired");
    }

    private JwtService serviceAt(String instant) {
        return new JwtService(new ObjectMapper(),
                Clock.fixed(Instant.parse(instant), ZoneOffset.UTC), SECRET, 3600);
    }
}
