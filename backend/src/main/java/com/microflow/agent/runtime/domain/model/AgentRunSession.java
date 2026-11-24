package com.microflow.agent.runtime.domain.model;

/** A durable agent run: the unit of context, steps, approvals, artifacts and audit. */
public record AgentRunSession(
        String id,
        String workspaceId,
        String taskId,
        String channelId,
        String triggerMessageId,
        String initiatorUserId,
        String agentKey,
        String runKind,
        AgentRunStatus status,
        String goal,
        String contextSummary,
        String errorMessage,
        String interruptionState,
        String resumedFromSessionId,
        int stepCount,
        int approvalWaitCount,
        int attemptCount,
        String createdAt,
        String startedAt,
        String finishedAt,
        String updatedAt
) {

    public boolean isInterrupted() {
        return "INTERRUPTED".equalsIgnoreCase(interruptionState);
    }

    public String scopeLabel() {
        if (taskId != null && !taskId.isBlank()) {
            return "TASK";
        }
        if (channelId != null && !channelId.isBlank()) {
            return "CHANNEL";
        }
        return "WORKSPACE";
    }
}
