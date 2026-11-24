package com.microflow.agent.runtime.domain.model;

/** One entry of the append-only run event log. {@code seq} is per-run and gapless. */
public record AgentRunEvent(
        String id,
        String sessionId,
        String workspaceId,
        long seq,
        String type,
        String payloadJson,
        String createdAt
) {
}
