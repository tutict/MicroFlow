package com.microflow.knowledge.api.rest;

import com.microflow.knowledge.api.dto.KnowledgeDocumentResponse;
import com.microflow.knowledge.api.mapper.KnowledgeApiMapper;
import com.microflow.knowledge.application.service.KnowledgeBaseService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.util.List;
import java.util.Locale;
import org.jboss.resteasy.plugins.providers.multipart.InputPart;
import org.jboss.resteasy.plugins.providers.multipart.MultipartFormDataInput;
import org.springframework.web.multipart.MultipartFile;

@Path("/api/v1/workspaces/{workspaceId}/knowledge-documents")
@Produces(MediaType.APPLICATION_JSON)
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

    @GET
    public List<KnowledgeDocumentResponse> listDocuments(
            @PathParam("workspaceId") String workspaceId,
            @Context HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return knowledgeBaseService.listDocuments(workspaceId, userId).stream()
                .map(knowledgeApiMapper::toResponse)
                .toList();
    }

    @POST
    @Consumes(MediaType.MULTIPART_FORM_DATA)
    public KnowledgeDocumentResponse uploadDocument(
            @PathParam("workspaceId") String workspaceId,
            MultipartFormDataInput formData,
            @Context HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        var filePart = firstPart(formData, "file");
        var channelId = textPart(formData, "channelId");
        return knowledgeApiMapper.toResponse(
                knowledgeBaseService.uploadDocument(workspaceId, userId, channelId, toMultipartFile(filePart))
        );
    }

    private InputPart firstPart(MultipartFormDataInput formData, String name) {
        var parts = formData.getFormDataMap().get(name);
        if (parts == null || parts.isEmpty()) {
            throw new IllegalArgumentException("Missing multipart field: " + name);
        }
        return parts.getFirst();
    }

    private String textPart(MultipartFormDataInput formData, String name) {
        var parts = formData.getFormDataMap().get(name);
        if (parts == null || parts.isEmpty()) {
            return null;
        }
        try {
            return parts.getFirst().getBodyAsString();
        } catch (IOException ex) {
            throw new IllegalArgumentException("Unable to read multipart field: " + name, ex);
        }
    }

    private MultipartFile toMultipartFile(InputPart part) {
        try {
            var bytes = part.getBody(byte[].class, null);
            var contentType = part.getMediaType() == null ? MediaType.APPLICATION_OCTET_STREAM : part.getMediaType().toString();
            var fileName = fileName(part);
            return new InMemoryMultipartFile("file", fileName, contentType, bytes);
        } catch (IOException ex) {
            throw new IllegalArgumentException("Unable to read uploaded file", ex);
        }
    }

    private String fileName(InputPart part) {
        var headers = part.getHeaders();
        var disposition = headers == null ? null : headers.getFirst(HttpHeaders.CONTENT_DISPOSITION);
        if (disposition == null || disposition.isBlank()) {
            return "document.txt";
        }
        for (var segment : disposition.split(";")) {
            var trimmed = segment.trim();
            if (trimmed.toLowerCase(Locale.ROOT).startsWith("filename=")) {
                return trimmed.substring("filename=".length()).replace("\"", "").trim();
            }
        }
        return "document.txt";
    }

    private record InMemoryMultipartFile(
            String name,
            String originalFilename,
            String contentType,
            byte[] bytes
    ) implements MultipartFile {

        @Override
        public String getName() {
            return name;
        }

        @Override
        public String getOriginalFilename() {
            return originalFilename;
        }

        @Override
        public String getContentType() {
            return contentType;
        }

        @Override
        public boolean isEmpty() {
            return bytes.length == 0;
        }

        @Override
        public long getSize() {
            return bytes.length;
        }

        @Override
        public byte[] getBytes() {
            return bytes;
        }

        @Override
        public InputStream getInputStream() {
            return new ByteArrayInputStream(bytes);
        }

        @Override
        public void transferTo(File dest) throws IOException {
            Files.write(dest.toPath(), bytes);
        }
    }
}
