package com.microflow.agent.api.dto;

public record AgentResponse(
        String agentKey,
        String provider,
        boolean enabled
) {
}

