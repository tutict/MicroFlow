package com.microflow.agent.runtime.domain.model;

/**
 * A single attempt to execute a tool call.
 *
 * <p>{@link Status#UNKNOWN} is the important one: the side effect may or may not
 * have happened (SMTP accepted the message but the connection dropped before the
 * response). Such an invocation blocks automatic retries until a human confirms
 * the external state.
 */
public record AgentToolInvocation(
        String id,
        String sessionId,
        String workspaceId,
        String stepId,
        String toolKey,
        String idempotencyKey,
        Status status,
        String riskLevel,
        String inputJson,
        String outputJson,
        String approvalId,
        String errorMessage,
        int attemptCount,
        String createdAt,
        String finishedAt
) {

    public enum Status {
        PENDING,
        AWAITING_APPROVAL,
        APPROVED,
        REJECTED,
        SUCCEEDED,
        FAILED,
        UNKNOWN,
        CANCELLED;

        public boolean isSettled() {
            return this == SUCCEEDED || this == FAILED || this == REJECTED || this == UNKNOWN || this == CANCELLED;
        }

        public static Status fromStored(String value) {
            if (value == null || value.isBlank()) {
                throw new IllegalArgumentException("Tool invocation status is required");
            }
            return valueOf(value.trim().toUpperCase(java.util.Locale.ROOT));
        }
    }
}
