package com.microflow.chat.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SendMessageRequest(
        @NotBlank String workspaceId,
        @NotBlank @Size(max = 4000) String content
) {
}
