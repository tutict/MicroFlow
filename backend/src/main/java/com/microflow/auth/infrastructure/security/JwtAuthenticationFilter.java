package com.microflow.auth.infrastructure.security;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.inject.Inject;
import jakarta.ws.rs.Priorities;
import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.container.ContainerRequestFilter;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.ext.Provider;
import java.util.Map;

@Provider
@jakarta.annotation.Priority(Priorities.AUTHENTICATION)
public class JwtAuthenticationFilter implements ContainerRequestFilter {

    @Inject
    JwtService jwtService;

    @Context
    HttpServletRequest servletRequest;

    @Override
    public void filter(ContainerRequestContext requestContext) {
        var path = resolvePath(requestContext);
        if (shouldNotFilter(requestContext.getMethod(), path)) {
            return;
        }
        var header = requestContext.getHeaderString(HttpHeaders.AUTHORIZATION);
        if (header == null || !header.startsWith("Bearer ")) {
            abort(requestContext, "Missing bearer token");
            return;
        }
        try {
            var principal = jwtService.verify(header.substring(7));
            if (servletRequest != null) {
                servletRequest.setAttribute("currentUserId", principal.userId());
                servletRequest.setAttribute("currentUserEmail", principal.email());
                servletRequest.setAttribute("currentDisplayName", principal.displayName());
            }
        } catch (IllegalArgumentException ex) {
            abort(requestContext, ex.getMessage() == null ? "Invalid JWT" : ex.getMessage());
        }
    }

    private boolean shouldNotFilter(String method, String path) {
        var normalizedPath = path.startsWith("/") ? path.substring(1) : path;
        return "OPTIONS".equalsIgnoreCase(method)
                || normalizedPath.startsWith("api/v1/system/")
                || normalizedPath.startsWith("api/v1/bootstrap/")
                || normalizedPath.startsWith("bootstrap/")
                || normalizedPath.equals("api/v1/auth/login")
                || normalizedPath.equals("api/v1/auth/register")
                || normalizedPath.equals("api/v1/auth/refresh")
                || normalizedPath.equals("api/v1/auth/logout")
                || normalizedPath.equals("auth/login")
                || normalizedPath.equals("auth/register")
                || normalizedPath.equals("auth/refresh")
                || normalizedPath.equals("auth/logout")
                || normalizedPath.startsWith("q/")
                || normalizedPath.startsWith("ws");
    }

    private String resolvePath(ContainerRequestContext requestContext) {
        if (servletRequest != null && servletRequest.getRequestURI() != null) {
            return servletRequest.getRequestURI();
        }
        return "/" + requestContext.getUriInfo().getPath(false);
    }

    private void abort(ContainerRequestContext requestContext, String message) {
        requestContext.abortWith(Response.status(Response.Status.UNAUTHORIZED)
                .entity(Map.of(
                        "status", Response.Status.UNAUTHORIZED.getStatusCode(),
                        "error", "Unauthorized",
                        "message", message
                ))
                .build());
    }
}

