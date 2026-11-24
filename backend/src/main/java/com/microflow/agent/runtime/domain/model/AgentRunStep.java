package com.microflow.agent.runtime.domain.model;

/** A human-readable step inside a run: context build, agent turn or tool action. */
public record AgentRunStep(
        String id,
        String sessionId,
        int seq,
        String stepKind,
        String status,
        String agentKey,
        String title,
        String detail,
        String startedAt,
        String finishedAt
) {
}
