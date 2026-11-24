package com.microflow.knowledge.domain.model;

/** A ranked knowledge excerpt returned to an agent tool. */
public record KnowledgeSnippet(
        String documentId,
        String fileName,
        String channelId,
        String content,
        int score
) {
}
