package com.microflow.common.crypto;

public record EncryptedPayload(
        byte[] ciphertext,
        byte[] iv,
        Integer keyVersion
) {
}

