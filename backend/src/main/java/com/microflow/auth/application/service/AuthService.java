package com.microflow.auth.application.service;

import com.microflow.auth.domain.model.AuthTokens;
import com.microflow.auth.domain.model.UserProfile;

public interface AuthService {

    AuthTokens register(String email, String password, String displayName);

    AuthTokens login(String email, String password);

    void logout(String refreshToken);

    UserProfile currentUser(String userId);
}
