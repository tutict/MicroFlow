package com.microflow.chat.domain.model;

import java.util.List;

public record CollaborationRunSummary(
        String collaborationId,
        String workspaceId,
        String channelId,
        String triggerMessageId,
        String status,
        String stage,
        String activeAgentKey,
        List<String> agentKeys,
        String trigger,
        String reason,
        int round,
        int maxRounds,
        String detail,
        String startedAt,
        String lastEventAt,
        List<CollaborationEventLog> events
) {
}
