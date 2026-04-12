package com.microflow.bootstrap.pairing;

public record PairingChallengeResponse(
        String instanceName,
        String pairingCode,
        String expiresAt,
        String serverOrigin,
        String apiBaseUrl,
        String wsBaseUrl,
        String qrPayload
) {
}
