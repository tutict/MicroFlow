package com.microflow.agent.runtime.domain.model;

/** An approval request raised before an external side effect. */
public record AgentApproval(
        String id,
        String sessionId,
        String workspaceId,
        String stepId,
        String toolKey,
        String action,
        String targetResource,
        String riskLevel,
        String impactSummary,
        String inputJson,
        AgentApprovalStatus status,
        String decidedByUserId,
        String decisionNote,
        String createdAt,
        String decidedAt
) {
}
