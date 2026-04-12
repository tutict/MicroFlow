package com.microflow.auth.api.dto;

public record UserProfileResponse(
        String userId,
        String email,
        String displayName
) {
}

