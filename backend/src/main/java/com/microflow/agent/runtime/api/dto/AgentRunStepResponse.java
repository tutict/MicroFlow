package com.microflow.agent.runtime.api.dto;

public record AgentRunStepResponse(
        String id,
        int seq,
        String kind,
        String status,
        String agentKey,
        String title,
        String detail,
        String startedAt,
        String finishedAt
) {
}
