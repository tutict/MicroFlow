package com.microflow.agent.runtime.domain.model;

/**
 * A source the context builder actually used.
 *
 * <p>Only a reference plus an excerpt is stored. The full mailbox or file is
 * never copied into the run record, so an audit trail cannot become a second
 * inbox.
 */
public record AgentContextSource(
        String id,
        String sessionId,
        String workspaceId,
        String sourceType,
        String refId,
        String label,
        String excerpt,
        boolean included,
        String createdAt
) {
}
