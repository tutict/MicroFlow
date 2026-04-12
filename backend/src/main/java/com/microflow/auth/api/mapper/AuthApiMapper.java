package com.microflow.auth.api.mapper;

import com.microflow.auth.api.dto.AuthTokensResponse;
import com.microflow.auth.api.dto.UserProfileResponse;
import com.microflow.auth.domain.model.AuthTokens;
import com.microflow.auth.domain.model.UserProfile;
import org.springframework.stereotype.Component;

@Component
public class AuthApiMapper {

    public AuthTokensResponse toResponse(AuthTokens tokens) {
        return new AuthTokensResponse(
                tokens.accessToken(),
                tokens.refreshToken(),
                tokens.userId(),
                tokens.displayName()
        );
    }

    public UserProfileResponse toResponse(UserProfile profile) {
        return new UserProfileResponse(
                profile.userId(),
                profile.email(),
                profile.displayName()
        );
    }
}
