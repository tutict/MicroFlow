package com.microflow.auth.infrastructure.persistence;

public record UserAccountRow(
        String id,
        String email,
        String passwordHash,
        String displayName
) {
}
