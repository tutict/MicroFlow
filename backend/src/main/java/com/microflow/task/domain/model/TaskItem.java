package com.microflow.task.domain.model;

import java.time.Instant;

public record TaskItem(
        String id,
        String workspaceId,
        String projectId,
        String projectName,
        String title,
        String detail,
        TaskStatus status,
        TaskPriority priority,
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

    public boolean isUnassigned() {
        return assigneeUserId == null || assigneeUserId.isBlank();
    }
}
