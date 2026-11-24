package com.microflow.task.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateTaskRequest(
        String projectId,
        @NotBlank @Size(max = 200) String title,
        @Size(max = 4000) String detail,
        String status,
        String priority,
        String assigneeUserId,
        Boolean assigneeIsSelf,
        String originChannelId,
        String originMessageId,
        String dueAt
) {
}
