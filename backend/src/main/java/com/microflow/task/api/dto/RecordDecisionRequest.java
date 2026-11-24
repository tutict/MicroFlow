package com.microflow.task.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record RecordDecisionRequest(
        @NotBlank @Size(max = 300) String summary,
        @Size(max = 4000) String rationale,
        @Size(max = 4000) String alternativesConsidered,
        String supersedesDecisionId
) {
}
