package com.microflow.auth.infrastructure.security;

public record JwtPrincipal(
        String userId,
        String email,
        String displayName
) {
}

