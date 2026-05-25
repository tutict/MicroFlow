package com.microflow.accounting.api.dto;

import java.math.BigDecimal;

public record TrialBalanceRowResponse(
        String accountId,
        String accountCode,
        String accountName,
        String category,
        String normalBalance,
        BigDecimal debitAmount,
        BigDecimal creditAmount,
        BigDecimal balanceAmount,
        String balanceDirection
) {
}
