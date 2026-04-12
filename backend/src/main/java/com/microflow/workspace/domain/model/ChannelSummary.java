package com.microflow.workspace.domain.model;

public record ChannelSummary(
        String id,
        String name,
        int unreadCount
) {
}

