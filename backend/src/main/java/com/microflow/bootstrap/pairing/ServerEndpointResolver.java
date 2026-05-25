package com.microflow.bootstrap.pairing;

import jakarta.servlet.http.HttpServletRequest;
import java.util.Locale;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.springframework.stereotype.Component;

@Component
public class ServerEndpointResolver {

    private final String configuredServerOrigin;
    private final String configuredApiBaseUrl;
    private final String configuredWsBaseUrl;

    public ServerEndpointResolver(
            @ConfigProperty(name = "microflow.bootstrap.server-origin", defaultValue = " ") String configuredServerOrigin,
            @ConfigProperty(name = "microflow.bootstrap.api-base-url", defaultValue = " ") String configuredApiBaseUrl,
            @ConfigProperty(name = "microflow.bootstrap.ws-base-url", defaultValue = " ") String configuredWsBaseUrl,
            @ConfigProperty(name = "MICROFLOW_SERVER_ORIGIN", defaultValue = " ") String legacyServerOrigin,
            @ConfigProperty(name = "MICROFLOW_API_BASE_URL", defaultValue = " ") String legacyApiBaseUrl,
            @ConfigProperty(name = "MICROFLOW_WS_BASE_URL", defaultValue = " ") String legacyWsBaseUrl
    ) {
        this.configuredServerOrigin = firstConfigured(configuredServerOrigin, legacyServerOrigin);
        this.configuredApiBaseUrl = firstConfigured(configuredApiBaseUrl, legacyApiBaseUrl);
        this.configuredWsBaseUrl = firstConfigured(configuredWsBaseUrl, legacyWsBaseUrl);
    }

    public ResolvedEndpoints resolve(HttpServletRequest request) {
        var serverOrigin = normalizeConfiguredUrl(configuredServerOrigin);
        if (serverOrigin == null) {
            serverOrigin = deriveRequestOrigin(request);
        }

        var apiBaseUrl = normalizeConfiguredUrl(configuredApiBaseUrl);
        if (apiBaseUrl == null) {
            apiBaseUrl = serverOrigin + "/api/v1";
        }

        var wsBaseUrl = normalizeConfiguredUrl(configuredWsBaseUrl);
        if (wsBaseUrl == null) {
            wsBaseUrl = toWebSocketOrigin(serverOrigin) + "/ws";
        }

        return new ResolvedEndpoints(serverOrigin, apiBaseUrl, wsBaseUrl);
    }

    private String deriveRequestOrigin(HttpServletRequest request) {
        var host = effectiveHost(request);
        var localAddress = normalizeHost(request.getLocalAddr());
        if (!isLoopbackHost(host) && !host.equals(localAddress)) {
            throw new IllegalArgumentException(
                    "Non-local pairing origin must be configured via microflow.bootstrap.server-origin"
            );
        }
        var scheme = request.getScheme();
        var port = request.getServerPort();
        var defaultPort = ("http".equalsIgnoreCase(scheme) && port == 80)
                || ("https".equalsIgnoreCase(scheme) && port == 443);
        return defaultPort ? scheme + "://" + host : scheme + "://" + host + ":" + port;
    }

    private String effectiveHost(HttpServletRequest request) {
        var forwardedHost = firstForwardedHost(request.getHeader("Forwarded"));
        if (forwardedHost != null) {
            return normalizeHost(forwardedHost);
        }
        var xForwardedHost = firstListValue(request.getHeader("X-Forwarded-Host"));
        if (xForwardedHost != null) {
            return normalizeHost(xForwardedHost);
        }
        return normalizeHost(request.getServerName());
    }

    private String firstForwardedHost(String forwardedHeader) {
        if (forwardedHeader == null || forwardedHeader.isBlank()) {
            return null;
        }
        for (var segment : forwardedHeader.split(",")) {
            for (var directive : segment.split(";")) {
                var trimmed = directive.trim();
                if (!trimmed.regionMatches(true, 0, "host=", 0, 5)) {
                    continue;
                }
                var candidate = trimmed.substring(5).trim();
                if (candidate.startsWith("\"") && candidate.endsWith("\"") && candidate.length() >= 2) {
                    candidate = candidate.substring(1, candidate.length() - 1);
                }
                if (!candidate.isBlank()) {
                    return candidate;
                }
            }
        }
        return null;
    }

    private String firstListValue(String headerValue) {
        if (headerValue == null || headerValue.isBlank()) {
            return null;
        }
        for (var item : headerValue.split(",")) {
            var trimmed = item.trim();
            if (!trimmed.isBlank()) {
                return trimmed;
            }
        }
        return null;
    }

    private String normalizeConfiguredUrl(String configuredValue) {
        if (configuredValue == null) {
            return null;
        }
        var normalized = configuredValue.trim();
        if (normalized.isBlank()) {
            return null;
        }
        while (normalized.endsWith("/")) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }
        if (!normalized.startsWith("http://")
                && !normalized.startsWith("https://")
                && !normalized.startsWith("ws://")
                && !normalized.startsWith("wss://")) {
            throw new IllegalStateException("Configured MicroFlow endpoint URLs must include an explicit scheme");
        }
        return normalized;
    }

    private String firstConfigured(String primary, String fallback) {
        return primary != null && !primary.isBlank() ? primary : fallback;
    }

    private String toWebSocketOrigin(String httpOrigin) {
        if (httpOrigin.startsWith("https://")) {
            return "wss://" + httpOrigin.substring("https://".length());
        }
        if (httpOrigin.startsWith("http://")) {
            return "ws://" + httpOrigin.substring("http://".length());
        }
        return httpOrigin;
    }

    private String normalizeHost(String rawHost) {
        if (rawHost == null) {
            return "";
        }
        var host = rawHost.trim().toLowerCase(Locale.ROOT);
        if (host.startsWith("[")) {
            var closingIndex = host.indexOf(']');
            if (closingIndex > 0) {
                return host.substring(1, closingIndex);
            }
        }
        var colonCount = host.chars().filter(ch -> ch == ':').count();
        if (colonCount == 1) {
            return host.substring(0, host.indexOf(':'));
        }
        return host;
    }

    private boolean isLoopbackHost(String host) {
        return "localhost".equals(host)
                || "127.0.0.1".equals(host)
                || "::1".equals(host)
                || "0:0:0:0:0:0:0:1".equals(host)
                || host.startsWith("127.");
    }

    public record ResolvedEndpoints(
            String serverOrigin,
            String apiBaseUrl,
            String wsBaseUrl
    ) {
    }
}
