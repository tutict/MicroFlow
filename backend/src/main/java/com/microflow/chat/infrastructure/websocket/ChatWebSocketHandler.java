package com.microflow.chat.infrastructure.websocket;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.microflow.chat.api.ws.SocketSendMessagePayload;
import com.microflow.chat.api.ws.SocketSubscribePayload;
import com.microflow.chat.application.service.MessageApplicationService;
import com.microflow.realtime.session.WebSocketSessionRegistry;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

@Component
public class ChatWebSocketHandler extends TextWebSocketHandler {

    private static final Logger log = LoggerFactory.getLogger(ChatWebSocketHandler.class);

    private final ObjectMapper objectMapper;
    private final MessageApplicationService messageApplicationService;
    private final WebSocketSessionRegistry sessionRegistry;
    private final ExecutorService virtualThreadExecutorService;
    private final JdbcWorkspaceRepository workspaceRepository;

    public ChatWebSocketHandler(
            ObjectMapper objectMapper,
            MessageApplicationService messageApplicationService,
            WebSocketSessionRegistry sessionRegistry,
            ExecutorService virtualThreadExecutorService,
            JdbcWorkspaceRepository workspaceRepository
    ) {
        this.objectMapper = objectMapper;
        this.messageApplicationService = messageApplicationService;
        this.sessionRegistry = sessionRegistry;
        this.virtualThreadExecutorService = virtualThreadExecutorService;
        this.workspaceRepository = workspaceRepository;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        var userId = (String) session.getAttributes().get("currentUserId");
        sessionRegistry.register(session, userId);
        log.info("WebSocket connected: {}", session.getId());
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws IOException {
        virtualThreadExecutorService.submit(() -> processMessage(session, message));
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        sessionRegistry.unregister(session);
        log.info("WebSocket disconnected: {} ({})", session.getId(), status);
    }

    private void processMessage(WebSocketSession session, TextMessage message) {
        try {
            var envelope = objectMapper.readValue(message.getPayload(), Map.class);
            var type = (String) envelope.get("type");
            if ("SUBSCRIBE".equals(type)) {
                var payload = objectMapper.convertValue(envelope.get("payload"), SocketSubscribePayload.class);
                var userId = (String) session.getAttributes().get("currentUserId");
                if (!workspaceRepository.isChannelMember(payload.channelId(), userId)) {
                    throw new IllegalArgumentException("Channel access denied");
                }
                sessionRegistry.subscribe(session.getId(), payload.channelId());
                session.sendMessage(new TextMessage("{\"type\":\"SUBSCRIBED\"}"));
                return;
            }
            if ("CHAT_SEND".equals(type)) {
                var payload = objectMapper.convertValue(envelope.get("payload"), SocketSendMessagePayload.class);
                var userId = (String) session.getAttributes().get("currentUserId");
                var channelId = (String) envelope.get("channelId");
                messageApplicationService.sendMessage(payload.workspaceId(), channelId, userId, payload.content());
                session.sendMessage(new TextMessage("{\"type\":\"ACK\"}"));
                return;
            }
            session.sendMessage(new TextMessage("{\"type\":\"ERROR\",\"payload\":\"Unsupported event\"}"));
        } catch (Exception ex) {
            try {
                session.sendMessage(new TextMessage("{\"type\":\"ERROR\",\"payload\":\"" + sanitize(ex.getMessage()) + "\"}"));
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
