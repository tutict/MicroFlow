package com.microflow.bootstrap.pairing;

import jakarta.validation.constraints.NotBlank;

public record PairingRequest(
        @NotBlank String pairingCode
) {
}
