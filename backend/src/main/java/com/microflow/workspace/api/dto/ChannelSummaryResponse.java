package com.microflow.workspace.api.dto;

public record ChannelSummaryResponse(
        String id,
        String name,
        int unreadCount
) {
}

