package com.microflow.agent.domain.model;

import java.util.Map;

public record AgentExecutionRequest(
        String workspaceId,
        String channelId,
        String agentKey,
        String prompt,
        Map<String, Object> metadata
) {
}

