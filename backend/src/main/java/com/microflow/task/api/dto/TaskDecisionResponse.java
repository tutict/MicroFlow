package com.microflow.task.api.dto;

import java.time.Instant;

public record TaskDecisionResponse(
        String id,
        String workspaceId,
        String taskId,
        int sequenceNo,
        String supersedesDecisionId,
        String summary,
        String rationale,
        String alternativesConsidered,
        String decidedByUserId,
        String decidedByDisplayName,
        Instant createdAt
) {
}
