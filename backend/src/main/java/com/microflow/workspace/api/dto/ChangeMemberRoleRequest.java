package com.microflow.workspace.api.dto;

import jakarta.validation.constraints.NotBlank;

public record ChangeMemberRoleRequest(@NotBlank String role) {
}
