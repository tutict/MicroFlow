package com.microflow.accounting.api.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import java.util.List;

public record CreateAccountingVoucherRequest(
        @NotBlank @Size(max = 10) String voucherDate,
        @Size(max = 500) String description,
        @Valid @NotEmpty List<CreateAccountingVoucherLineRequest> lines
) {
}
