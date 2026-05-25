package com.microflow.accounting.domain.model;

import java.math.BigDecimal;

public record TrialBalanceRow(
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
