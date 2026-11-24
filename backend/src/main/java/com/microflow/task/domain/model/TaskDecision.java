package com.microflow.task.domain.model;

import java.time.Instant;

/**
 * An immutable decision record attached to a task.
 *
 * <p>A task may be redirected several times. Each redirection is a new record
 * that points at the one it replaces through {@code supersedesDecisionId}, so the
 * reasoning behind the current state stays recoverable instead of being
 * overwritten in place.
 */
public record TaskDecision(
        String id,
        String workspaceId,
        String taskId,
        int sequenceNo,
        String supersedesDecisionId,
        String summary,
        String rationale,
        String alternativesConsidered,
        String decidedByUserId,
        String decidedByDisplayName,
        Instant createdAt
) {
}
