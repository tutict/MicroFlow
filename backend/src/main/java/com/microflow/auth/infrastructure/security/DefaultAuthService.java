package com.microflow.auth.infrastructure.security;

import com.microflow.agent.config.DeploymentAgentCatalog;
import com.microflow.auth.application.service.AuthService;
import com.microflow.auth.domain.model.AuthTokens;
import com.microflow.auth.domain.model.UserProfile;
import com.microflow.auth.infrastructure.persistence.JdbcRefreshTokenRepository;
import com.microflow.auth.infrastructure.persistence.JdbcUserRepository;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import jakarta.transaction.Transactional;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class DefaultAuthService implements AuthService {

    private static final SecureRandom RANDOM = new SecureRandom();
    private static final Base64.Encoder URL_ENCODER = Base64.getUrlEncoder().withoutPadding();

    private final JdbcUserRepository userRepository;
    private final JdbcWorkspaceRepository workspaceRepository;
    private final JdbcRefreshTokenRepository refreshTokenRepository;
    private final PasswordHasher passwordHasher;
    private final JwtService jwtService;
    private final DeploymentAgentCatalog deploymentAgentCatalog;
    private final Clock clock;
    private final long refreshTtlSeconds;

    public DefaultAuthService(
            JdbcUserRepository userRepository,
            JdbcWorkspaceRepository workspaceRepository,
            JdbcRefreshTokenRepository refreshTokenRepository,
            PasswordHasher passwordHasher,
            JwtService jwtService,
            DeploymentAgentCatalog deploymentAgentCatalog,
            Clock clock,
            @Value("${microflow.jwt.refresh-ttl-seconds:2592000}") long refreshTtlSeconds
    ) {
        this.userRepository = userRepository;
        this.workspaceRepository = workspaceRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.passwordHasher = passwordHasher;
        this.jwtService = jwtService;
        this.deploymentAgentCatalog = deploymentAgentCatalog;
        this.clock = clock;
        this.refreshTtlSeconds = Math.max(60, refreshTtlSeconds);
    }

    @Override
    @Transactional
    public AuthTokens register(String email, String password, String displayName) {
        userRepository.findByEmail(email).ifPresent(existing -> {
            throw new IllegalArgumentException("Email already registered");
        });
        var created = userRepository.create(email, passwordHasher.hash(password), displayName);
        workspaceRepository.createDefaultWorkspace(
                created.id(),
                created.displayName(),
                deploymentAgentCatalog.discover()
        );
        return issueTokens(created.id(), created.email(), created.displayName());
    }

    @Override
    @Transactional
    public AuthTokens login(String email, String password) {
        var user = userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalArgumentException("Invalid email or password"));
        if (!passwordHasher.matches(password, user.passwordHash())) {
            throw new IllegalArgumentException("Invalid email or password");
        }
        return issueTokens(user.id(), user.email(), user.displayName());
    }

    @Override
    @Transactional
    public AuthTokens refresh(String refreshToken) {
        var now = Instant.now(clock);
        var tokenHash = hashRefreshToken(refreshToken);
        var refreshTokenRow = refreshTokenRepository.findActiveByHash(tokenHash, now)
                .orElseThrow(() -> new IllegalArgumentException("Invalid refresh token"));
        refreshTokenRepository.revokeByHash(tokenHash, now.toString());
        var user = userRepository.findById(refreshTokenRow.userId())
                .orElseThrow(() -> new IllegalArgumentException("Invalid refresh token"));
        return issueTokens(user.id(), user.email(), user.displayName());
    }

    @Override
    @Transactional
    public void logout(String refreshToken) {
        if (refreshToken == null || refreshToken.isBlank()) {
            return;
        }
        refreshTokenRepository.revokeByHash(hashRefreshToken(refreshToken), Instant.now(clock).toString());
    }

    @Override
    public UserProfile currentUser(String userId) {
        var user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("Unknown user"));
        return new UserProfile(user.id(), user.email(), user.displayName());
    }

    private AuthTokens issueTokens(String userId, String email, String displayName) {
        var accessToken = jwtService.issueToken(userId, email, displayName);
        var refreshToken = newRefreshToken();
        var now = Instant.now(clock);
        refreshTokenRepository.create(
                "rt_" + UUID.randomUUID(),
                userId,
                hashRefreshToken(refreshToken),
                now.plusSeconds(refreshTtlSeconds).toString(),
                now.toString()
        );
        return new AuthTokens(accessToken, refreshToken, userId, displayName);
    }

    private String newRefreshToken() {
        var raw = new byte[32];
        RANDOM.nextBytes(raw);
        return URL_ENCODER.encodeToString(raw);
    }

    private String hashRefreshToken(String refreshToken) {
        if (refreshToken == null || refreshToken.isBlank()) {
            throw new IllegalArgumentException("Refresh token is required");
        }
        try {
            var digest = MessageDigest.getInstance("SHA-256");
            return URL_ENCODER.encodeToString(digest.digest(refreshToken.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to hash refresh token", ex);
        }
    }
}
