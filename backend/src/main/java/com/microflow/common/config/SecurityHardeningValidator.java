package com.microflow.common.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class SecurityHardeningValidator {

    static final String DEFAULT_JWT_SECRET = "change-this-dev-jwt-secret-before-production";
    static final String DEFAULT_CRYPTO_SECRET = "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=";

    public SecurityHardeningValidator(
            @Value("${microflow.jwt.secret}") String jwtSecret,
            @Value("${microflow.crypto.secret}") String cryptoSecret,
            @Value("${microflow.security.allow-insecure-default-secrets:false}") boolean allowInsecureDefaultSecrets
    ) {
        if (allowInsecureDefaultSecrets) {
            return;
        }
        if (jwtSecret == null || jwtSecret.isBlank() || DEFAULT_JWT_SECRET.equals(jwtSecret)) {
            throw new IllegalStateException("microflow.jwt.secret must be overridden with a deployment-specific secret");
        }
        if (cryptoSecret == null || cryptoSecret.isBlank() || DEFAULT_CRYPTO_SECRET.equals(cryptoSecret)) {
            throw new IllegalStateException("microflow.crypto.secret must be overridden with a deployment-specific secret");
        }
    }
}
