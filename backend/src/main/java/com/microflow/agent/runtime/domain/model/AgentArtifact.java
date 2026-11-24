package com.microflow.agent.runtime.domain.model;

/** A durable output of a run, such as a draft or a summary. */
public record AgentArtifact(
        String id,
        String sessionId,
        String workspaceId,
        String artifactKind,
        String title,
        String summary,
        String contentText,
        String uri,
        String createdAt
) {
}
