package com.microflow.agent.runtime.api.dto;

import java.util.Map;

public record AgentToolInvocationResponse(
        String id,
        String runId,
        String toolKey,
        String status,
        String riskLevel,
        Map<String, Object> input,
        String output,
        String errorMessage,
        String approvalId,
        int attemptCount,
        String createdAt,
        String finishedAt
) {
}
