package com.microflow.workspace.domain.model;

public record WorkspaceMemberSummary(
        String userId,
        String email,
        String displayName,
        String role,
        String joinedAt
) {
}
