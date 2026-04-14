package com.microflow.workspace.api.dto;

public record WorkspaceMemberSummaryResponse(
        String userId,
        String email,
        String displayName,
        String role,
        String joinedAt
) {
}
