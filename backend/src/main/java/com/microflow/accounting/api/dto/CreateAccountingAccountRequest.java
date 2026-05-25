package com.microflow.accounting.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateAccountingAccountRequest(
        @NotBlank @Size(max = 40) String code,
        @NotBlank @Size(max = 160) String name,
        @NotBlank @Size(max = 32) String category,
        @NotBlank @Size(max = 16) String normalBalance
) {
}
