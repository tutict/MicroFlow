package com.microflow.workspace.api.dto;

public record ConversationSummaryResponse(
        String id,
        String title,
        String subtitle,
        String kind,
        int unreadCount,
        boolean available,
        String lastActivityAt
) {
}
