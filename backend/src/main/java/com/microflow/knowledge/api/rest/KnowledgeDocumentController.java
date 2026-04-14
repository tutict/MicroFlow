package com.microflow.knowledge.api.rest;

import com.microflow.knowledge.api.dto.KnowledgeDocumentResponse;
import com.microflow.knowledge.api.mapper.KnowledgeApiMapper;
import com.microflow.knowledge.application.service.KnowledgeBaseService;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/workspaces/{workspaceId}/knowledge-documents")
public class KnowledgeDocumentController {

    private final KnowledgeBaseService knowledgeBaseService;
    private final KnowledgeApiMapper knowledgeApiMapper;

    public KnowledgeDocumentController(
            KnowledgeBaseService knowledgeBaseService,
            KnowledgeApiMapper knowledgeApiMapper
    ) {
        this.knowledgeBaseService = knowledgeBaseService;
        this.knowledgeApiMapper = knowledgeApiMapper;
    }

    @GetMapping
    public List<KnowledgeDocumentResponse> listDocuments(
            @PathVariable String workspaceId,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return knowledgeBaseService.listDocuments(workspaceId, userId).stream()
                .map(knowledgeApiMapper::toResponse)
                .toList();
    }

    @PostMapping(consumes = "multipart/form-data")
    public KnowledgeDocumentResponse uploadDocument(
            @PathVariable String workspaceId,
            @RequestParam("file") MultipartFile file,
            @RequestParam(required = false) String channelId,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return knowledgeApiMapper.toResponse(
                knowledgeBaseService.uploadDocument(workspaceId, userId, channelId, file)
        );
    }
}
