package com.microflow.knowledge.api.dto;

public record KnowledgeDocumentResponse(
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
