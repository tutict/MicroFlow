package com.microflow.agent.runtime.api.dto;

public record AgentArtifactResponse(
        String id,
        String runId,
        String kind,
        String title,
        String summary,
        String content,
        String uri,
        String createdAt
) {
}
