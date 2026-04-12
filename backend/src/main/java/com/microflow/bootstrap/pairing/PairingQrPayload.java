package com.microflow.bootstrap.pairing;

public record PairingQrPayload(
        String instanceName,
        String pairingCode,
        String serverOrigin,
        String apiBaseUrl,
        String wsBaseUrl,
        String expiresAt
) {
}
