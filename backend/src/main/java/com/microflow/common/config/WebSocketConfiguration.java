package com.microflow.common.config;

import com.microflow.chat.infrastructure.websocket.ChatWebSocketHandler;
import java.util.Arrays;
import org.springframework.context.annotation.Configuration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

@Configuration(proxyBeanMethods = false)
@EnableWebSocket
public class WebSocketConfiguration implements WebSocketConfigurer {

    private final ChatWebSocketHandler chatWebSocketHandler;
    private final WebSocketAuthenticationHandshakeInterceptor webSocketAuthenticationHandshakeInterceptor;
    private final String[] allowedOriginPatterns;

    public WebSocketConfiguration(
            ChatWebSocketHandler chatWebSocketHandler,
            WebSocketAuthenticationHandshakeInterceptor webSocketAuthenticationHandshakeInterceptor,
            @Value("${microflow.websocket.allowed-origin-patterns:http://localhost:*,http://127.0.0.1:*,https://localhost:*,https://127.0.0.1:*}") String allowedOriginPatterns
    ) {
        this.chatWebSocketHandler = chatWebSocketHandler;
        this.webSocketAuthenticationHandshakeInterceptor = webSocketAuthenticationHandshakeInterceptor;
        this.allowedOriginPatterns = Arrays.stream(allowedOriginPatterns.split(","))
                .map(String::trim)
                .filter(value -> !value.isBlank())
                .toArray(String[]::new);
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(chatWebSocketHandler, "/ws")
                .addInterceptors(webSocketAuthenticationHandshakeInterceptor)
                .setAllowedOriginPatterns(allowedOriginPatterns);
    }
}
