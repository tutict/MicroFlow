package com.microflow.accounting.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record CreateAccountingVoucherLineRequest(
        @NotBlank String accountId,
        @Size(max = 500) String summary,
        BigDecimal debitAmount,
        BigDecimal creditAmount
) {
}
