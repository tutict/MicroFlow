package com.microflow.knowledge.domain.model;

public record KnowledgeChunk(
        String documentId,
        String fileName,
        String channelId,
        String content,
        int chunkIndex,
        String chunkCreatedAt,
        String documentCreatedAt
) {
}
