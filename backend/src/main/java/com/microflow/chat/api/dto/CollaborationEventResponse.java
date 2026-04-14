package com.microflow.chat.api.dto;

public record CollaborationEventResponse(
        String id,
        String workspaceId,
        String channelId,
        String collaborationId,
        String eventType,
        String status,
        String stage,
        String agentKey,
        String trigger,
        int round,
        int maxRounds,
        String detail,
        String createdAt
) {
}
