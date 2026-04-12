package com.microflow.common.config;

import com.microflow.auth.infrastructure.security.JwtPrincipal;
import com.microflow.auth.infrastructure.security.JwtService;
import com.microflow.auth.infrastructure.security.WebSocketTicketService;
import java.util.Map;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.http.server.ServletServerHttpRequest;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.server.HandshakeInterceptor;

@Component
public class WebSocketAuthenticationHandshakeInterceptor implements HandshakeInterceptor {

    private final JwtService jwtService;
    private final WebSocketTicketService webSocketTicketService;

    public WebSocketAuthenticationHandshakeInterceptor(
            JwtService jwtService,
            WebSocketTicketService webSocketTicketService
    ) {
        this.jwtService = jwtService;
        this.webSocketTicketService = webSocketTicketService;
    }

    @Override
    public boolean beforeHandshake(
            ServerHttpRequest request,
            ServerHttpResponse response,
            WebSocketHandler wsHandler,
            Map<String, Object> attributes
    ) {
        try {
            JwtPrincipal principal = null;
            if (request instanceof ServletServerHttpRequest servletRequest) {
                var ticket = servletRequest.getServletRequest().getParameter("ticket");
                if (ticket != null) {
                    principal = webSocketTicketService.consume(ticket);
                }
            }
            if (principal == null) {
                var authHeader = request.getHeaders().getFirst(HttpHeaders.AUTHORIZATION);
                if (authHeader != null && authHeader.startsWith("Bearer ")) {
                    principal = jwtService.verify(authHeader.substring(7));
                }
            }
            if (principal == null) {
                response.setStatusCode(HttpStatus.UNAUTHORIZED);
                return false;
            }
            attributes.put("currentUserId", principal.userId());
            attributes.put("currentUserEmail", principal.email());
            attributes.put("currentDisplayName", principal.displayName());
            return true;
        } catch (IllegalArgumentException ex) {
            response.setStatusCode(HttpStatus.UNAUTHORIZED);
            return false;
        }
    }

    @Override
    public void afterHandshake(
            ServerHttpRequest request,
            ServerHttpResponse response,
            WebSocketHandler wsHandler,
            Exception exception
    ) {
    }
}
