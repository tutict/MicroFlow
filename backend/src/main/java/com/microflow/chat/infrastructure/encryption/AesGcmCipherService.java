package com.microflow.chat.infrastructure.encryption;

import com.microflow.common.crypto.EncryptedPayload;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class AesGcmCipherService implements CipherService {

    private static final SecureRandom RANDOM = new SecureRandom();

    private final SecretKeySpec secretKeySpec;
    private final int keyVersion;

    public AesGcmCipherService(
            @Value("${microflow.crypto.secret}") String base64Secret,
            @Value("${microflow.crypto.key-version:1}") int keyVersion
    ) {
        this.secretKeySpec = new SecretKeySpec(Base64.getDecoder().decode(base64Secret), "AES");
        this.keyVersion = keyVersion;
    }

    @Override
    public EncryptedPayload encrypt(String plaintext) {
        try {
            var iv = new byte[12];
            RANDOM.nextBytes(iv);
            var cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, secretKeySpec, new GCMParameterSpec(128, iv));
            var ciphertext = cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));
            return new EncryptedPayload(ciphertext, iv, keyVersion);
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to encrypt message", ex);
        }
    }

    @Override
    public String decrypt(EncryptedPayload payload) {
        try {
            var cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, secretKeySpec, new GCMParameterSpec(128, payload.iv()));
            return new String(cipher.doFinal(payload.ciphertext()), StandardCharsets.UTF_8);
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to decrypt message", ex);
        }
    }
}

