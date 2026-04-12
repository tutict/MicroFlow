package com.microflow.auth.api.rest;

import com.microflow.auth.api.dto.AuthTokensResponse;
import com.microflow.auth.api.dto.LoginRequest;
import com.microflow.auth.api.dto.RegisterRequest;
import com.microflow.auth.api.dto.UserProfileResponse;
import com.microflow.auth.api.dto.WebSocketTicketResponse;
import com.microflow.auth.api.mapper.AuthApiMapper;
import com.microflow.auth.application.service.AuthService;
import com.microflow.auth.infrastructure.security.LoginAttemptRateLimiter;
import com.microflow.auth.infrastructure.security.WebSocketTicketService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final AuthService authService;
    private final AuthApiMapper authApiMapper;
    private final WebSocketTicketService webSocketTicketService;
    private final LoginAttemptRateLimiter loginAttemptRateLimiter;

    public AuthController(
            AuthService authService,
            AuthApiMapper authApiMapper,
            WebSocketTicketService webSocketTicketService,
            LoginAttemptRateLimiter loginAttemptRateLimiter
    ) {
        this.authService = authService;
        this.authApiMapper = authApiMapper;
        this.webSocketTicketService = webSocketTicketService;
        this.loginAttemptRateLimiter = loginAttemptRateLimiter;
    }

    @PostMapping("/login")
    public ResponseEntity<AuthTokensResponse> login(
            @Valid @RequestBody LoginRequest request,
            HttpServletRequest httpRequest
    ) {
        var remoteAddress = httpRequest.getRemoteAddr();
        loginAttemptRateLimiter.checkAllowed(request.email(), remoteAddress);
        var tokens = attemptLogin(request, remoteAddress);
        return ResponseEntity.ok(authApiMapper.toResponse(tokens));
    }

    @PostMapping("/register")
    public ResponseEntity<AuthTokensResponse> register(@Valid @RequestBody RegisterRequest request) {
        var tokens = authService.register(request.email(), request.password(), request.displayName());
        return ResponseEntity.ok(authApiMapper.toResponse(tokens));
    }

    @GetMapping("/me")
    public ResponseEntity<UserProfileResponse> me(HttpServletRequest request) {
        var userId = (String) request.getAttribute("currentUserId");
        return ResponseEntity.ok(authApiMapper.toResponse(authService.currentUser(userId)));
    }

    @PostMapping("/ws-ticket")
    public ResponseEntity<WebSocketTicketResponse> issueWebSocketTicket(HttpServletRequest request) {
        var grant = webSocketTicketService.issue(
                (String) request.getAttribute("currentUserId"),
                (String) request.getAttribute("currentUserEmail"),
                (String) request.getAttribute("currentDisplayName")
        );
        return ResponseEntity.ok(new WebSocketTicketResponse(
                grant.ticket(),
                grant.expiresAt().toString()
        ));
    }

    private com.microflow.auth.domain.model.AuthTokens attemptLogin(LoginRequest request, String remoteAddress) {
        try {
            var tokens = authService.login(request.email(), request.password());
            loginAttemptRateLimiter.recordSuccess(request.email(), remoteAddress);
            return tokens;
        } catch (IllegalArgumentException ex) {
            loginAttemptRateLimiter.recordFailure(request.email(), remoteAddress);
            throw ex;
        }
    }
}
