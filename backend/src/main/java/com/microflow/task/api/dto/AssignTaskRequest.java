package com.microflow.task.api.dto;

public record AssignTaskRequest(
        String assigneeUserId,
        Boolean assigneeIsSelf
) {
}
