package com.microflow.agent.runtime.api.dto;

public record StartAgentRunRequest(
        String agentKey,
        String goal
) {
}
