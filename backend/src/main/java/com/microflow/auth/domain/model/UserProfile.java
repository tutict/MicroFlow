package com.microflow.auth.domain.model;

public record UserProfile(
        String userId,
        String email,
        String displayName
) {
}

