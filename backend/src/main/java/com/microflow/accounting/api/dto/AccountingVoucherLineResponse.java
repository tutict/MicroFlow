package com.microflow.accounting.api.dto;

import java.math.BigDecimal;

public record AccountingVoucherLineResponse(
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
