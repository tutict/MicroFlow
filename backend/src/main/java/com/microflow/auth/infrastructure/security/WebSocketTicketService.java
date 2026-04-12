package com.microflow.auth.infrastructure.security;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class WebSocketTicketService {

    private static final SecureRandom RANDOM = new SecureRandom();
    private static final Base64.Encoder URL_ENCODER = Base64.getUrlEncoder().withoutPadding();

    private final Clock clock;
    private final Duration ttl;
    private final Map<String, TicketEntry> tickets = new ConcurrentHashMap<>();

    public WebSocketTicketService(
            Clock clock,
            @Value("${microflow.websocket.ticket-ttl:PT30S}") Duration ttl
    ) {
        this.clock = clock;
        this.ttl = ttl;
    }

    public TicketGrant issue(String userId, String email, String displayName) {
        evictExpired();
        var raw = new byte[32];
        RANDOM.nextBytes(raw);
        var ticket = URL_ENCODER.encodeToString(raw);
        var expiresAt = Instant.now(clock).plus(ttl);
        tickets.put(ticket, new TicketEntry(
                new JwtPrincipal(userId, email, displayName),
                expiresAt
        ));
        return new TicketGrant(ticket, expiresAt);
    }

    public JwtPrincipal consume(String ticket) {
        evictExpired();
        if (ticket == null || ticket.isBlank()) {
            throw new IllegalArgumentException("Missing WebSocket ticket");
        }
        var entry = tickets.remove(ticket);
        if (entry == null || entry.expiresAt().isBefore(Instant.now(clock))) {
            throw new IllegalArgumentException("Invalid or expired WebSocket ticket");
        }
        return entry.principal();
    }

    private void evictExpired() {
        var now = Instant.now(clock);
        tickets.entrySet().removeIf(entry -> entry.getValue().expiresAt().isBefore(now));
    }

    public record TicketGrant(
            String ticket,
            Instant expiresAt
    ) {
    }

    private record TicketEntry(
            JwtPrincipal principal,
            Instant expiresAt
    ) {
    }
}
