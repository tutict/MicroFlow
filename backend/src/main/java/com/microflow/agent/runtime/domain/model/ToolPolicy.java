package com.microflow.agent.runtime.domain.model;

/**
 * Execution policy for a tool.
 *
 * <p>{@link Permission#AUTO} tools only read data or write MicroFlow-internal
 * drafts. Anything that leaves the process must go through
 * {@link Permission#APPROVAL}, so an agent can never mutate the outside world
 * on its own.
 */
public final class ToolPolicy {

    private ToolPolicy() {
    }

    public enum Permission {
        AUTO,
        APPROVAL
    }

    /**
     * How much damage a tool can do. The runtime uses this for the approval card
     * wording and for deciding whether an uncertain result blocks a retry.
     */
    public enum Risk {
        READ_ONLY,
        INTERNAL_WRITE,
        EXTERNAL_WRITE,
        DESTRUCTIVE;

        public boolean isExternal() {
            return this == EXTERNAL_WRITE || this == DESTRUCTIVE;
        }
    }
}
