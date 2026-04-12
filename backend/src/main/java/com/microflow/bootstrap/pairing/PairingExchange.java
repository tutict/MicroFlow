package com.microflow.bootstrap.pairing;

import java.time.Instant;

public record PairingExchange(
        String instanceName,
        Instant pairedAt
) {
}
