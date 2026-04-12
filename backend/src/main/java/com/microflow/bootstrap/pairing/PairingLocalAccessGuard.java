package com.microflow.bootstrap.pairing;

import jakarta.servlet.http.HttpServletRequest;
import java.util.Locale;
import org.springframework.stereotype.Component;

@Component
public class PairingLocalAccessGuard {

    public void ensureLocalRequest(HttpServletRequest request) {
        var clientAddress = normalizeAddress(resolveClientAddress(request));
        var requestedHost = normalizeHost(resolveRequestedHost(request));
        if (clientAddress == null || !isLoopbackAddress(clientAddress) || !isLoopbackHost(requestedHost)) {
            throw new IllegalArgumentException("Pairing console is only available from the local machine");
        }
    }

    private String resolveClientAddress(HttpServletRequest request) {
        var forwarded = request.getHeader("Forwarded");
        var forwardedClient = firstForwardedFor(forwarded);
        if (forwardedClient != null) {
            return forwardedClient;
        }

        var xForwardedFor = firstListValue(request.getHeader("X-Forwarded-For"));
        if (xForwardedFor != null) {
            return xForwardedFor;
        }

        var xRealIp = request.getHeader("X-Real-IP");
        if (xRealIp != null && !xRealIp.isBlank()) {
            return xRealIp.trim();
        }

        return request.getRemoteAddr();
    }

    private String resolveRequestedHost(HttpServletRequest request) {
        var forwardedHost = firstForwardedHost(request.getHeader("Forwarded"));
        if (forwardedHost != null) {
            return forwardedHost;
        }
        var xForwardedHost = firstListValue(request.getHeader("X-Forwarded-Host"));
        if (xForwardedHost != null) {
            return xForwardedHost;
        }
        return request.getServerName();
    }

    private String firstForwardedFor(String forwardedHeader) {
        if (forwardedHeader == null || forwardedHeader.isBlank()) {
            return null;
        }
        for (var segment : forwardedHeader.split(",")) {
            for (var directive : segment.split(";")) {
                var trimmed = directive.trim();
                if (!trimmed.regionMatches(true, 0, "for=", 0, 4)) {
                    continue;
                }
                var candidate = trimmed.substring(4).trim();
                if (candidate.startsWith("\"") && candidate.endsWith("\"") && candidate.length() >= 2) {
                    candidate = candidate.substring(1, candidate.length() - 1);
                }
                if (!candidate.isBlank() && !"unknown".equalsIgnoreCase(candidate)) {
                    return candidate;
                }
            }
        }
        return null;
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
                if (!candidate.isBlank() && !"unknown".equalsIgnoreCase(candidate)) {
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
            if (!trimmed.isBlank() && !"unknown".equalsIgnoreCase(trimmed)) {
                return trimmed;
            }
        }
        return null;
    }

    private String normalizeAddress(String rawAddress) {
        if (rawAddress == null) {
            return null;
        }
        var normalized = rawAddress.trim().toLowerCase(Locale.ROOT);
        if (normalized.startsWith("[")) {
            var closingIndex = normalized.indexOf(']');
            if (closingIndex > 0) {
                return normalized.substring(1, closingIndex);
            }
        }
        var colonCount = normalized.chars().filter(ch -> ch == ':').count();
        if (colonCount == 1 && normalized.contains(".")) {
            return normalized.substring(0, normalized.indexOf(':'));
        }
        return normalized;
    }

    private String normalizeHost(String rawHost) {
        if (rawHost == null) {
            return "";
        }
        var normalized = rawHost.trim().toLowerCase(Locale.ROOT);
        if (normalized.startsWith("[")) {
            var closingIndex = normalized.indexOf(']');
            if (closingIndex > 0) {
                return normalized.substring(1, closingIndex);
            }
        }
        var colonCount = normalized.chars().filter(ch -> ch == ':').count();
        if (colonCount == 1) {
            return normalized.substring(0, normalized.indexOf(':'));
        }
        return normalized;
    }

    private boolean isLoopbackHost(String host) {
        return "localhost".equals(host)
                || isLoopbackAddress(host);
    }

    private boolean isLoopbackAddress(String remoteAddress) {
        return "127.0.0.1".equals(remoteAddress)
                || "::1".equals(remoteAddress)
                || "0:0:0:0:0:0:0:1".equals(remoteAddress)
                || remoteAddress.startsWith("::ffff:127.0.0.1")
                || remoteAddress.startsWith("127.");
    }
}
