package com.microflow.auth.api.dto;

public record AuthTokensResponse(
        String accessToken,
        String refreshToken,
        String userId,
        String displayName
) {
}

