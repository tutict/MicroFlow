package com.microflow.knowledge.domain.model;

import java.util.Objects;

/** File content passed from the HTTP multipart boundary to knowledge ingestion. */
public record KnowledgeUpload(String fileName, String contentType, byte[] content) {
    public KnowledgeUpload {
        content = Objects.requireNonNull(content, "content").clone();
    }

    @Override
    public byte[] content() {
        return content.clone();
    }

    public long sizeBytes() {
        return content.length;
    }

    public boolean isEmpty() {
        return content.length == 0;
    }
}
