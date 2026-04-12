package com.microflow.auth.infrastructure.security;

import com.microflow.agent.config.DeploymentAgentCatalog;
import com.microflow.auth.application.service.AuthService;
import com.microflow.auth.domain.model.AuthTokens;
import com.microflow.auth.domain.model.UserProfile;
import com.microflow.auth.infrastructure.persistence.JdbcUserRepository;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import org.springframework.stereotype.Service;

@Service
public class DefaultAuthService implements AuthService {

    private final JdbcUserRepository userRepository;
    private final JdbcWorkspaceRepository workspaceRepository;
    private final PasswordHasher passwordHasher;
    private final JwtService jwtService;
    private final DeploymentAgentCatalog deploymentAgentCatalog;

    public DefaultAuthService(
            JdbcUserRepository userRepository,
            JdbcWorkspaceRepository workspaceRepository,
            PasswordHasher passwordHasher,
            JwtService jwtService,
            DeploymentAgentCatalog deploymentAgentCatalog
    ) {
        this.userRepository = userRepository;
        this.workspaceRepository = workspaceRepository;
        this.passwordHasher = passwordHasher;
        this.jwtService = jwtService;
        this.deploymentAgentCatalog = deploymentAgentCatalog;
    }

    @Override
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
    public AuthTokens login(String email, String password) {
        var user = userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalArgumentException("Invalid email or password"));
        if (!passwordHasher.matches(password, user.passwordHash())) {
            throw new IllegalArgumentException("Invalid email or password");
        }
        return issueTokens(user.id(), user.email(), user.displayName());
    }

    @Override
    public void logout(String refreshToken) {
        // Stateless JWT flow for the minimal runnable version.
    }

    @Override
    public UserProfile currentUser(String userId) {
        var user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("Unknown user"));
        return new UserProfile(user.id(), user.email(), user.displayName());
    }

    private AuthTokens issueTokens(String userId, String email, String displayName) {
        var accessToken = jwtService.issueToken(userId, email, displayName);
        var refreshToken = jwtService.issueToken(userId, email, displayName);
        return new AuthTokens(accessToken, refreshToken, userId, displayName);
    }
}
