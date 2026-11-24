package com.microflow.task.domain.model;

public record TaskProject(
        String id,
        String workspaceId,
        String name,
        String description,
        String status,
        String createdByUserId,
        long taskCount,
        long openTaskCount
) {
}
