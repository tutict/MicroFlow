package com.microflow.chat.infrastructure.encryption;

import com.microflow.common.crypto.EncryptedPayload;

public interface CipherService {

    EncryptedPayload encrypt(String plaintext);

    String decrypt(EncryptedPayload payload);
}

