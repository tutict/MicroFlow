package com.microflow.agent.runtime.api.dto;

public record DecideApprovalRequest(
        String decision,
        String note
) {
}
