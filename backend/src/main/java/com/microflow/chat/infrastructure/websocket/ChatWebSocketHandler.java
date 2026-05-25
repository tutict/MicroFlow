package com.microflow.chat.infrastructure.websocket;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.microflow.auth.infrastructure.security.JwtPrincipal;
import com.microflow.auth.infrastructure.security.WebSocketTicketService;
import com.microflow.chat.api.ws.SocketSendMessagePayload;
import com.microflow.chat.api.ws.SocketSubscribePayload;
import com.microflow.chat.application.service.MessageApplicationService;
import com.microflow.realtime.session.WebSocketSessionRegistry;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.websocket.CloseReason;
import jakarta.websocket.OnClose;
import jakarta.websocket.OnMessage;
import jakarta.websocket.OnOpen;
import jakarta.websocket.Session;
import jakarta.websocket.server.ServerEndpoint;
import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@ApplicationScoped
@ServerEndpoint("/ws")
public class ChatWebSocketHandler {

    private static final Logger log = LoggerFactory.getLogger(ChatWebSocketHandler.class);

    @Inject
    ObjectMapper objectMapper;

    @Inject
    MessageApplicationService messageApplicationService;

    @Inject
    WebSocketSessionRegistry sessionRegistry;

    @Inject
    @Named("microflowVirtualThreadExecutor")
    ExecutorService virtualThreadExecutorService;

    @Inject
    JdbcWorkspaceRepository workspaceRepository;

    @Inject
    WebSocketTicketService webSocketTicketService;

    @OnOpen
    public void onOpen(Session session) throws IOException {
        try {
            var principal = authenticate(session);
            session.getUserProperties().put("currentUserId", principal.userId());
            session.getUserProperties().put("currentUserEmail", principal.email());
            session.getUserProperties().put("currentDisplayName", principal.displayName());
            sessionRegistry.register(session, principal.userId());
            log.info("WebSocket connected: {}", session.getId());
        } catch (IllegalArgumentException ex) {
            session.close(new CloseReason(CloseReason.CloseCodes.VIOLATED_POLICY, "Unauthorized"));
        }
    }

    @OnMessage
    public void onMessage(Session session, String message) {
        virtualThreadExecutorService.submit(() -> processMessage(session, message));
    }

    @OnClose
    public void onClose(Session session, CloseReason closeReason) {
        sessionRegistry.unregister(session);
        log.info("WebSocket disconnected: {} ({})", session.getId(), closeReason);
    }

    private JwtPrincipal authenticate(Session session) {
        var tickets = session.getRequestParameterMap().get("ticket");
        var ticket = tickets == null || tickets.isEmpty() ? null : tickets.getFirst();
        if (ticket == null || ticket.isBlank()) {
            throw new IllegalArgumentException("Missing WebSocket ticket");
        }
        return webSocketTicketService.consume(ticket);
    }

    private void processMessage(Session session, String message) {
        try {
            var envelope = objectMapper.readValue(message, Map.class);
            var type = (String) envelope.get("type");
            if ("SUBSCRIBE".equals(type)) {
                var payload = objectMapper.convertValue(envelope.get("payload"), SocketSubscribePayload.class);
                var userId = (String) session.getUserProperties().get("currentUserId");
                if (!workspaceRepository.isChannelMember(payload.channelId(), userId)) {
                    throw new IllegalArgumentException("Channel access denied");
                }
                sessionRegistry.subscribe(session.getId(), payload.channelId());
                session.getBasicRemote().sendText("{\"type\":\"SUBSCRIBED\"}");
                return;
            }
            if ("CHAT_SEND".equals(type)) {
                var payload = objectMapper.convertValue(envelope.get("payload"), SocketSendMessagePayload.class);
                var userId = (String) session.getUserProperties().get("currentUserId");
                var channelId = (String) envelope.get("channelId");
                messageApplicationService.sendMessage(payload.workspaceId(), channelId, userId, payload.content());
                session.getBasicRemote().sendText("{\"type\":\"ACK\"}");
                return;
            }
            session.getBasicRemote().sendText("{\"type\":\"ERROR\",\"payload\":\"Unsupported event\"}");
        } catch (Exception ex) {
            try {
                session.getBasicRemote().sendText("{\"type\":\"ERROR\",\"payload\":\"" + sanitize(ex.getMessage()) + "\"}");
            } catch (IOException ignored) {
                log.debug("Unable to send websocket error response", ignored);
            }
        }
    }

    private String sanitize(String message) {
        if (message == null || message.isBlank()) {
            return "WebSocket processing failed";
        }
        return message.replace("\"", "'");
    }
}
