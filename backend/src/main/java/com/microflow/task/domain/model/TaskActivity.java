package com.microflow.task.domain.model;

import java.time.Instant;

public record TaskActivity(
        String id,
        String taskId,
        String workspaceId,
        String actorUserId,
        String actorDisplayName,
        String eventType,
        String fromValue,
        String toValue,
        String note,
        Instant createdAt
) {
}
