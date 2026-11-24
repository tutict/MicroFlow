package com.microflow.task.api.dto;

public record TaskSummaryResponse(
        long total,
        long open,
        long inProgress,
        long blocked,
        long done
) {
}
