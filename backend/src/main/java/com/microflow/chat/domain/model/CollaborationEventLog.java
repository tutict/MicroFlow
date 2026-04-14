package com.microflow.chat.domain.model;

public record CollaborationEventLog(
        String id,
        String workspaceId,
        String channelId,
        String collaborationId,
        String triggerMessageId,
        String eventType,
        String status,
        String stage,
        String agentKey,
        String reason,
        String agentKeys,
        String trigger,
        int round,
        int maxRounds,
        String detail,
        String createdAt
) {
}
