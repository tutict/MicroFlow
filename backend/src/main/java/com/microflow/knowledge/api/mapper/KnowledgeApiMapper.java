package com.microflow.knowledge.api.mapper;

import com.microflow.knowledge.api.dto.KnowledgeDocumentResponse;
import com.microflow.knowledge.domain.model.KnowledgeDocumentSummary;
import org.springframework.stereotype.Component;

@Component
public class KnowledgeApiMapper {

    public KnowledgeDocumentResponse toResponse(KnowledgeDocumentSummary document) {
        return new KnowledgeDocumentResponse(
                document.id(),
                document.workspaceId(),
                document.channelId(),
                document.fileName(),
                document.contentType(),
                document.sizeBytes(),
                document.summary(),
                document.snippetCount(),
                document.status(),
                document.createdAt()
        );
    }
}
