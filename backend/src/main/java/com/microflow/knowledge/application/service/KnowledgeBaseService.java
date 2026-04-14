package com.microflow.knowledge.application.service;

import com.microflow.chat.infrastructure.persistence.JdbcMessageRepository;
import com.microflow.knowledge.domain.model.KnowledgeChunk;
import com.microflow.knowledge.domain.model.KnowledgeDocumentSummary;
import com.microflow.knowledge.infrastructure.persistence.JdbcKnowledgeRepository;
import com.microflow.realtime.broadcaster.RealtimeBroadcaster;
import com.microflow.realtime.protocol.RealtimeEvent;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class KnowledgeBaseService {

    private static final Pattern TOKEN_SPLIT_PATTERN = Pattern.compile("[^\\p{L}\\p{N}]+");
    private static final Pattern CONTROL_PATTERN = Pattern.compile("[\\p{Cntrl}&&[^\\r\\n\\t]]");
    private static final Set<String> ALLOWED_EXTENSIONS = Set.of(
            ".txt", ".md", ".markdown", ".json", ".yaml", ".yml", ".log",
            ".csv", ".xml", ".java", ".kt", ".dart", ".js", ".ts", ".tsx",
            ".jsx", ".sql", ".properties", ".env"
    );
    private static final Set<String> STOP_WORDS = Set.of(
            "the", "and", "for", "with", "that", "this", "from", "into",
            "about", "have", "will", "your", "you", "are", "was", "were"
    );

    private final JdbcKnowledgeRepository knowledgeRepository;
    private final JdbcWorkspaceRepository workspaceRepository;
    private final JdbcMessageRepository messageRepository;
    private final RealtimeBroadcaster realtimeBroadcaster;
    private final Clock clock;
    private final Path uploadRoot;
    private final int maxUploadSizeBytes;
    private final int retrievalMaxSnippets;

    public KnowledgeBaseService(
            JdbcKnowledgeRepository knowledgeRepository,
            JdbcWorkspaceRepository workspaceRepository,
            JdbcMessageRepository messageRepository,
            RealtimeBroadcaster realtimeBroadcaster,
            Clock clock,
            @Value("${MICROFLOW_DATA_DIR:./data}") String dataDir,
            @Value("${microflow.knowledge.max-upload-size-bytes:5242880}") int maxUploadSizeBytes,
            @Value("${microflow.knowledge.retrieval-max-snippets:3}") int retrievalMaxSnippets
    ) {
        this.knowledgeRepository = knowledgeRepository;
        this.workspaceRepository = workspaceRepository;
        this.messageRepository = messageRepository;
        this.realtimeBroadcaster = realtimeBroadcaster;
        this.clock = clock;
        this.uploadRoot = Path.of(dataDir).resolve("knowledge");
        this.maxUploadSizeBytes = Math.max(1024, maxUploadSizeBytes);
        this.retrievalMaxSnippets = Math.max(1, retrievalMaxSnippets);
    }

    public List<KnowledgeDocumentSummary> listDocuments(String workspaceId, String userId) {
        ensureWorkspaceMember(workspaceId, userId);
        return knowledgeRepository.listDocuments(workspaceId);
    }

    public KnowledgeDocumentSummary uploadDocument(
            String workspaceId,
            String userId,
            String channelId,
            MultipartFile file
    ) {
        ensureWorkspaceMember(workspaceId, userId);
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("A non-empty file is required");
        }
        if (file.getSize() > maxUploadSizeBytes) {
            throw new IllegalArgumentException(
                    "Knowledge upload must be %s bytes or smaller".formatted(maxUploadSizeBytes)
            );
        }
        var fileName = sanitizeFileName(file.getOriginalFilename());
        var contentType = normalizeContentType(file.getContentType());
        validateUploadType(fileName, contentType);
        try {
            var bytes = file.getBytes();
            rejectBinaryPayload(bytes);
            var extractedText = extractText(bytes).trim();
            if (extractedText.isBlank()) {
                throw new IllegalArgumentException("The uploaded file did not contain readable text");
            }
            Files.createDirectories(uploadRoot.resolve(workspaceId));
            var documentId = "doc_" + UUID.randomUUID();
            var storagePath = uploadRoot.resolve(workspaceId).resolve(documentId + "-" + fileName);
            Files.write(storagePath, bytes);
            var chunks = chunkText(extractedText);
            var now = Instant.now(clock).toString();
            var targetChannelId = resolveTargetChannelId(workspaceId, channelId);
            knowledgeRepository.saveDocument(
                    documentId,
                    workspaceId,
                    userId,
                    targetChannelId,
                    fileName,
                    contentType,
                    file.getSize(),
                    storagePath.toString(),
                    summarize(extractedText),
                    chunks.size(),
                    now
            );
            knowledgeRepository.replaceChunks(documentId, workspaceId, chunks, now);
            var document = knowledgeRepository.findDocument(documentId)
                    .orElseThrow(() -> new IllegalStateException("Uploaded document could not be loaded"));
            publishKnowledgeUploadMessage(workspaceId, targetChannelId, document);
            return document;
        } catch (IllegalArgumentException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to persist knowledge document", ex);
        }
    }

    public String buildContextBlock(String workspaceId, String channelId, String query) {
        var allChunks = knowledgeRepository.listChunks(workspaceId, 80);
        if (allChunks.isEmpty()) {
            return "";
        }
        var queryTokens = tokenize(query);
        var rankedChunks = allChunks.stream()
                .map(chunk -> new RankedChunk(chunk, scoreChunk(chunk, channelId, queryTokens)))
                .filter(chunk -> !queryTokens.isEmpty() ? chunk.score() > 0 : true)
                .sorted(Comparator
                        .comparingInt(RankedChunk::score)
                        .reversed()
                        .thenComparing((RankedChunk ranked) -> ranked.chunk().documentCreatedAt(), Comparator.reverseOrder())
                        .thenComparing(ranked -> ranked.chunk().chunkIndex()))
                .limit(retrievalMaxSnippets)
                .toList();
        if (rankedChunks.isEmpty()) {
            return "";
        }
        var context = new StringBuilder("Relevant workspace sources:\n");
        for (var rankedChunk : rankedChunks) {
            context.append("[kb:")
                    .append(rankedChunk.chunk().documentId())
                    .append("] ")
                    .append(rankedChunk.chunk().fileName());
            if (rankedChunk.chunk().channelId() != null && !rankedChunk.chunk().channelId().isBlank()) {
                context.append(" (channel ").append(rankedChunk.chunk().channelId()).append(")");
            }
            context.append(": ")
                    .append(truncate(rankedChunk.chunk().content(), 260))
                    .append('\n');
        }
        context.append("When you rely on these sources, cite them inline as [kb:documentId].");
        return context.toString().trim();
    }

    List<String> chunkText(String text) {
        var normalized = text.replace("\r", "")
                .replaceAll("[\\t ]+", " ")
                .replaceAll("\\n{3,}", "\n\n")
                .trim();
        if (normalized.isBlank()) {
            return List.of();
        }
        var paragraphs = normalized.split("\\n\\n");
        var chunks = new ArrayList<String>();
        var current = new StringBuilder();
        for (var paragraph : paragraphs) {
            var candidate = paragraph.trim();
            if (candidate.isBlank()) {
                continue;
            }
            if (current.length() > 0 && current.length() + candidate.length() + 2 > 720) {
                chunks.add(current.toString().trim());
                current = new StringBuilder(overlapTail(current.toString(), 120));
            }
            if (current.length() > 0) {
                current.append("\n\n");
            }
            current.append(candidate);
        }
        if (current.length() > 0) {
            chunks.add(current.toString().trim());
        }
        return chunks.stream()
                .map(String::trim)
                .filter(value -> !value.isBlank())
                .limit(12)
                .toList();
    }

    private void ensureWorkspaceMember(String workspaceId, String userId) {
        if (!workspaceRepository.isWorkspaceMember(workspaceId, userId)) {
            throw new IllegalArgumentException("Workspace access denied");
        }
    }

    private String extractText(byte[] bytes) {
        var decoded = new String(bytes, StandardCharsets.UTF_8);
        return CONTROL_PATTERN.matcher(decoded).replaceAll("");
    }

    private String summarize(String text) {
        return truncate(text.replaceAll("\\s+", " ").trim(), 180);
    }

    private int scoreChunk(KnowledgeChunk chunk, String currentChannelId, Set<String> queryTokens) {
        var score = 0;
        if (currentChannelId != null
                && !currentChannelId.isBlank()
                && currentChannelId.equals(chunk.channelId())) {
            score += 6;
        }
        score += recencyScore(chunk.documentCreatedAt());
        if (queryTokens.isEmpty()) {
            return score + 1;
        }
        var normalized = chunk.content().toLowerCase(Locale.ROOT);
        for (var token : queryTokens) {
            if (normalized.contains(token)) {
                score += token.length() >= 6 ? 3 : 2;
            }
        }
        return score;
    }

    private int recencyScore(String createdAt) {
        if (createdAt == null || createdAt.isBlank()) {
            return 0;
        }
        try {
            var ageHours = java.time.Duration.between(Instant.parse(createdAt), Instant.now(clock)).toHours();
            if (ageHours <= 24) {
                return 4;
            }
            if (ageHours <= 24 * 7) {
                return 2;
            }
        } catch (Exception ignored) {
            return 0;
        }
        return 0;
    }

    private Set<String> tokenize(String query) {
        if (query == null || query.isBlank()) {
            return Set.of();
        }
        return TOKEN_SPLIT_PATTERN.splitAsStream(query.toLowerCase(Locale.ROOT))
                .map(String::trim)
                .filter(token -> token.length() >= 2)
                .filter(token -> !STOP_WORDS.contains(token))
                .collect(Collectors.toCollection(LinkedHashSet::new));
    }

    private String overlapTail(String value, int maxChars) {
        var trimmed = value.trim();
        if (trimmed.length() <= maxChars) {
            return trimmed;
        }
        return trimmed.substring(trimmed.length() - maxChars);
    }

    private String sanitizeFileName(String originalFilename) {
        var raw = originalFilename == null ? "document.txt" : originalFilename.trim();
        if (raw.isBlank()) {
            raw = "document.txt";
        }
        return raw.replaceAll("[^A-Za-z0-9._-]", "_");
    }

    private String normalizeContentType(String contentType) {
        if (contentType == null || contentType.isBlank()) {
            return "application/octet-stream";
        }
        return contentType.trim();
    }

    private void validateUploadType(String fileName, String contentType) {
        var normalizedType = contentType.toLowerCase(Locale.ROOT);
        if (normalizedType.startsWith("text/")
                || normalizedType.contains("json")
                || normalizedType.contains("xml")
                || normalizedType.contains("yaml")
                || normalizedType.contains("csv")) {
            return;
        }
        if (hasAllowedExtension(fileName)) {
            return;
        }
        throw new IllegalArgumentException("Only text-like knowledge documents are supported right now");
    }

    private boolean hasAllowedExtension(String fileName) {
        var normalizedFileName = fileName.toLowerCase(Locale.ROOT);
        for (final var extension : ALLOWED_EXTENSIONS) {
            if (normalizedFileName.endsWith(extension)) {
                return true;
            }
        }
        return false;
    }

    private void rejectBinaryPayload(byte[] bytes) {
        for (var index = 0; index < Math.min(bytes.length, 2048); index++) {
            if (bytes[index] == 0) {
                throw new IllegalArgumentException("Binary files are not supported for knowledge upload");
            }
        }
    }

    private String resolveTargetChannelId(String workspaceId, String requestedChannelId) {
        if (requestedChannelId != null
                && !requestedChannelId.isBlank()
                && workspaceRepository.isChannelInWorkspace(workspaceId, requestedChannelId)) {
            return requestedChannelId;
        }
        var knowledgeChannelId = workspaceRepository.findChannelIdByWorkspaceAndName(workspaceId, "knowledge");
        if (knowledgeChannelId != null && !knowledgeChannelId.isBlank()) {
            return knowledgeChannelId;
        }
        var generalChannelId = workspaceRepository.findChannelIdByWorkspaceAndName(workspaceId, "general");
        if (generalChannelId != null && !generalChannelId.isBlank()) {
            return generalChannelId;
        }
        throw new IllegalStateException("No available channel exists for knowledge notifications");
    }

    private void publishKnowledgeUploadMessage(
            String workspaceId,
            String channelId,
            KnowledgeDocumentSummary document
    ) {
        var summary = document.summary() == null || document.summary().isBlank()
                ? document.contentType()
                : document.summary();
        var message = messageRepository.saveAgentMessage(
                workspaceId,
                channelId,
                "system",
                "Knowledge uploaded: %s\nSummary: %s\nCite as [%s] when relevant."
                        .formatted(document.fileName(), summary, "kb:" + document.id())
        );
        realtimeBroadcaster.publishToChannel(channelId, new RealtimeEvent("MESSAGE_CREATED", message));
    }

    private String truncate(String value, int maxLength) {
        if (value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength) + "...";
    }

    private record RankedChunk(KnowledgeChunk chunk, int score) {
    }
}
