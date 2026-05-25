package com.microflow.accounting.api.dto;

public record AccountingAccountResponse(
        String id,
        String workspaceId,
        String code,
        String name,
        String category,
        String normalBalance,
        boolean active,
        String createdAt,
        String updatedAt
) {
}
