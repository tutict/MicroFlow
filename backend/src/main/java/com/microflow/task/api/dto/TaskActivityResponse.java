package com.microflow.task.api.dto;

import java.time.Instant;

public record TaskActivityResponse(
        String id,
        String taskId,
        String actorUserId,
        String actorDisplayName,
        String eventType,
        String fromValue,
        String toValue,
        String note,
        Instant createdAt
) {
}
