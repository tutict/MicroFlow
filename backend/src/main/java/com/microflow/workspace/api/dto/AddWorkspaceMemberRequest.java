package com.microflow.workspace.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record AddWorkspaceMemberRequest(
        @NotBlank
        @Email
        String email
) {
}
