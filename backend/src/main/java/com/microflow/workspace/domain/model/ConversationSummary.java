package com.microflow.workspace.domain.model;

public record ConversationSummary(
        String id,
        String title,
        String subtitle,
        ConversationKind kind,
        int unreadCount,
        boolean available,
        String lastActivityAt
) {
}
