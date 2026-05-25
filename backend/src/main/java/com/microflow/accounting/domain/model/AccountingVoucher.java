package com.microflow.accounting.domain.model;

import java.math.BigDecimal;
import java.util.List;

public record AccountingVoucher(
        String id,
        String workspaceId,
        String voucherNo,
        String voucherDate,
        String period,
        String status,
        String description,
        BigDecimal totalDebit,
        BigDecimal totalCredit,
        String createdByUserId,
        String createdAt,
        String updatedAt,
        String postedAt,
        List<AccountingVoucherLine> lines
) {
}
