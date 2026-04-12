package com.microflow.bootstrap.pairing;

import java.time.Instant;

public record PairingChallenge(
        String code,
        Instant expiresAt
) {
}
