package com.microflow.realtime.broadcaster;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.microflow.realtime.protocol.RealtimeEvent;
import com.microflow.realtime.session.WebSocketSessionRegistry;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.websocket.Session;
import java.io.IOException;
import java.util.Map;

@ApplicationScoped
public class DefaultRealtimeBroadcaster implements RealtimeBroadcaster {

    private final ObjectMapper objectMapper;
    private final WebSocketSessionRegistry sessionRegistry;

    public DefaultRealtimeBroadcaster(ObjectMapper objectMapper, WebSocketSessionRegistry sessionRegistry) {
        this.objectMapper = objectMapper;
        this.sessionRegistry = sessionRegistry;
    }

    @Override
    public void publishToChannel(String channelId, RealtimeEvent event) {
        var payload = serialize(event);
        sessionRegistry.subscribedToChannel(channelId)
                .forEach(context -> send(context.session(), payload));
    }

    @Override
    public void publishToUser(String userId, RealtimeEvent event) {
        var payload = serialize(event);
        sessionRegistry.forUser(userId)
                .forEach(context -> send(context.session(), payload));
    }

    private String serialize(RealtimeEvent event) {
        try {
            return objectMapper.writeValueAsString(Map.of(
                    "type", event.type(),
                    "payload", event.payload()
            ));
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to serialize realtime event", ex);
        }
    }

    private void send(Session session, String payload) {
        if (!session.isOpen()) {
            return;
        }
        synchronized (session) {
            try {
                session.getBasicRemote().sendText(payload);
            } catch (IOException ignored) {
                // Session lifecycle is best-effort for the minimal runnable backend.
            }
        }
    }
}
