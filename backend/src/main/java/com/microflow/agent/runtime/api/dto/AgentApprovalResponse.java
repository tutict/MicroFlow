package com.microflow.agent.runtime.api.dto;

import java.util.Map;

public record AgentApprovalResponse(
        String id,
        String runId,
        String toolKey,
        String action,
        String targetResource,
        String riskLevel,
        String impactSummary,
        Map<String, Object> input,
        String status,
        String decidedByUserId,
        String note,
        String createdAt,
        String decidedAt
) {
}
