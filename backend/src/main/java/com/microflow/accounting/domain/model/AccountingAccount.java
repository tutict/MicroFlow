package com.microflow.accounting.domain.model;

public record AccountingAccount(
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
