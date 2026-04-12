package com.microflow.auth.api.dto;

public record WebSocketTicketResponse(
        String ticket,
        String expiresAt
) {
}
