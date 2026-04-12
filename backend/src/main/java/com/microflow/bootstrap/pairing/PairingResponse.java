package com.microflow.bootstrap.pairing;

public record PairingResponse(
        String instanceName,
        String serverOrigin,
        String apiBaseUrl,
        String wsBaseUrl,
        String pairedAt
) {
}
