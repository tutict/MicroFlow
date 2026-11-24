package com.microflow.agent.runtime.domain.tool;

/** Everything a tool is allowed to know about the run that called it. */
public record ToolContext(
        String sessionId,
        String workspaceId,
        String taskId,
        String channelId,
        String initiatorUserId,
        String agentKey,
        String approvalId
) {
}
