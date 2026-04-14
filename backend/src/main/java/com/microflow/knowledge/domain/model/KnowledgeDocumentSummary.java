package com.microflow.knowledge.domain.model;

public record KnowledgeDocumentSummary(
        String id,
        String workspaceId,
        String channelId,
        String fileName,
        String contentType,
        long sizeBytes,
        String summary,
        int snippetCount,
        String status,
        String createdAt
) {
}
