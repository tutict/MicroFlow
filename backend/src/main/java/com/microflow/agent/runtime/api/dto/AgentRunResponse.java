package com.microflow.agent.runtime.api.dto;

public record AgentRunResponse(
        String id,
        String workspaceId,
        String taskId,
        String channelId,
        String initiatorUserId,
        String agentKey,
        String kind,
        String status,
        String goal,
        String contextSummary,
        String errorMessage,
        String interruptionState,
        int stepCount,
        int approvalWaitCount,
        int attemptCount,
        String pendingApprovalId,
        String createdAt,
        String startedAt,
        String finishedAt,
        String updatedAt
) {
}
