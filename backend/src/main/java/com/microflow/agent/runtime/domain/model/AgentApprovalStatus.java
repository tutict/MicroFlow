package com.microflow.agent.runtime.domain.model;

public enum AgentApprovalStatus {

    PENDING,
    APPROVED,
    REJECTED,
    CANCELLED;

    public boolean isPending() {
        return this == PENDING;
    }

    public static AgentApprovalStatus fromStored(String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("Approval status is required");
        }
        return valueOf(value.trim().toUpperCase(java.util.Locale.ROOT));
    }
}
