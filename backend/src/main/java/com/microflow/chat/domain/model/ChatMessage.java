package com.microflow.chat.domain.model;

import java.time.Instant;

public record ChatMessage(
        String id,
        String workspaceId,
        String channelId,
        String senderUserId,
        String content,
        Instant createdAt
) {
}

