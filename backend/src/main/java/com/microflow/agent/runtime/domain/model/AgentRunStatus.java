package com.microflow.agent.runtime.domain.model;

import java.util.EnumSet;
import java.util.Set;

/**
 * Lifecycle of one durable agent run.
 *
 * <p>The transition table lives here instead of being scattered across the
 * runtime service so an illegal move (for example approving a cancelled run)
 * fails at the same place every time. Terminal states never move again; a retry
 * is a new attempt on the same record and is modelled explicitly through
 * {@link #canRetry()}.
 */
public enum AgentRunStatus {

    QUEUED,
    CONTEXT_BUILDING,
    RUNNING,
    WAITING_APPROVAL,
    SUCCEEDED,
    FAILED,
    CANCELLED;

    private static final Set<AgentRunStatus> ACTIVE = EnumSet.of(
            QUEUED, CONTEXT_BUILDING, RUNNING, WAITING_APPROVAL
    );

    public boolean isTerminal() {
        return !ACTIVE.contains(this);
    }

    public boolean isActive() {
        return ACTIVE.contains(this);
    }

    /** Whether {@code next} is reachable from this status. */
    public boolean canTransitionTo(AgentRunStatus next) {
        if (next == null) {
            return false;
        }
        return switch (this) {
            case QUEUED -> next == CONTEXT_BUILDING || next == CANCELLED || next == FAILED;
            case CONTEXT_BUILDING -> next == RUNNING || next == FAILED || next == CANCELLED;
            case RUNNING -> next == WAITING_APPROVAL
                    || next == SUCCEEDED
                    || next == FAILED
                    || next == CANCELLED;
            case WAITING_APPROVAL -> next == RUNNING
                    || next == FAILED
                    || next == CANCELLED
                    || next == SUCCEEDED;
            case SUCCEEDED, FAILED, CANCELLED -> false;
        };
    }

    /** A failed run may be retried; other terminal states may not. */
    public boolean canRetry() {
        return this == FAILED;
    }

    public static AgentRunStatus fromStored(String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("Agent run status is required");
        }
        return valueOf(value.trim().toUpperCase(java.util.Locale.ROOT));
    }
}
