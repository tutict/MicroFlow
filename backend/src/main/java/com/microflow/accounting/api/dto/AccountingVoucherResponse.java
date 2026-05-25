package com.microflow.accounting.api.dto;

import java.math.BigDecimal;
import java.util.List;

public record AccountingVoucherResponse(
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
        List<AccountingVoucherLineResponse> lines
) {
}
