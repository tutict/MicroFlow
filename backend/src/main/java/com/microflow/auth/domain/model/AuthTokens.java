package com.microflow.auth.domain.model;

public record AuthTokens(
        String accessToken,
        String refreshToken,
        String userId,
        String displayName
) {
}

