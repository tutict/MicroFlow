package com.microflow.task.api.dto;

public record TaskProjectResponse(
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
