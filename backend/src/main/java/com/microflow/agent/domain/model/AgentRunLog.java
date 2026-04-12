package com.microflow.agent.domain.model;

public record AgentRunLog(
        String id,
        String agentKey,
        String status,
        String triggerMessageId,
        String resultMessageId,
        String createdAt,
        String finishedAt,
        String errorMessage
) {
}
