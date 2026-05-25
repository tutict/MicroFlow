package com.microflow.realtime.session;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.websocket.Session;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@ApplicationScoped
public class WebSocketSessionRegistry {

    private final Map<String, SessionContext> sessions = new ConcurrentHashMap<>();

    public void register(Session session, String userId) {
        sessions.put(session.getId(), new SessionContext(session, userId));
    }

    public void unregister(Session session) {
        sessions.remove(session.getId());
    }

    public void subscribe(String sessionId, String channelId) {
        var context = sessions.get(sessionId);
        if (context != null) {
            context.subscribedChannels().add(channelId);
        }
    }

    public Set<SessionContext> subscribedToChannel(String channelId) {
        return sessions.values().stream()
                .filter(context -> context.subscribedChannels().contains(channelId))
                .collect(java.util.stream.Collectors.toSet());
    }

    public Set<SessionContext> forUser(String userId) {
        return sessions.values().stream()
                .filter(context -> context.userId().equals(userId))
                .collect(java.util.stream.Collectors.toSet());
    }

    public record SessionContext(
            Session session,
            String userId,
            Set<String> subscribedChannels
    ) {
        SessionContext(Session session, String userId) {
            this(session, userId, ConcurrentHashMap.newKeySet());
        }
    }
}
