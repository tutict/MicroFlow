package com.microflow.task.api.dto;

import java.time.Instant;

public record TaskResponse(
        String id,
        String workspaceId,
        String projectId,
        String projectName,
        String title,
        String detail,
        String status,
        String priority,
        String assigneeUserId,
        String assigneeDisplayName,
        String creatorUserId,
        String originChannelId,
        String originMessageId,
        Instant dueAt,
        Instant createdAt,
        Instant updatedAt,
        Instant completedAt
) {
}
