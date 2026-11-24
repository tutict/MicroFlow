package com.microflow.agent.runtime.api.dto;

public record AgentContextSourceResponse(
        String id,
        String type,
        String label,
        String refId,
        String excerpt
) {
}
