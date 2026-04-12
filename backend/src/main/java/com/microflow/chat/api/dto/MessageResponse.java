package com.microflow.chat.api.dto;

public record MessageResponse(
        String id,
        String workspaceId,
        String channelId,
        String senderUserId,
        String content,
        String createdAt
) {
}

