package com.microflow.agent.api.dto;

public record AgentRunResponse(
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

