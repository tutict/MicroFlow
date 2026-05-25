package com.microflow.accounting.domain.model;

import java.math.BigDecimal;

public record AccountingVoucherLine(
        String id,
        String voucherId,
        int lineNo,
        String accountId,
        String accountCode,
        String accountName,
        String summary,
        BigDecimal debitAmount,
        BigDecimal creditAmount
) {
}
