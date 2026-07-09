package com.microflow.auth.infrastructure.persistence;

public record RefreshTokenRow(
        String id,
        String userId,
        String tokenHash,
        String expiresAt,
        String revokedAt,
        String createdAt
) {
}
