package com.microflow.workspace.api.dto;

public record WorkspaceSummaryResponse(
        String id,
        String name,
        int memberCount
) {
}

