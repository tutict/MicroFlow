package com.microflow.knowledge.infrastructure.persistence;

import com.microflow.knowledge.domain.model.KnowledgeChunk;
import com.microflow.knowledge.domain.model.KnowledgeDocumentSummary;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcKnowledgeRepository {

    private static final RowMapper<KnowledgeDocumentSummary> DOCUMENT_MAPPER = JdbcKnowledgeRepository::mapDocument;
    private static final RowMapper<KnowledgeChunk> CHUNK_MAPPER = JdbcKnowledgeRepository::mapChunk;

    private final JdbcTemplate jdbcTemplate;

    public JdbcKnowledgeRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void saveDocument(
            String documentId,
            String workspaceId,
            String uploaderUserId,
            String channelId,
            String fileName,
            String contentType,
            long sizeBytes,
            String storagePath,
            String summary,
            int snippetCount,
            String now
    ) {
        jdbcTemplate.update("""
                INSERT INTO knowledge_documents(
                    id, workspace_id, uploader_user_id, channel_id, file_name, content_type,
                    size_bytes, storage_path, summary, snippet_count, status, created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'READY', ?, ?)
                """,
                documentId,
                workspaceId,
                uploaderUserId,
                channelId,
                fileName,
                contentType,
                sizeBytes,
                storagePath,
                summary,
                snippetCount,
                now,
                now
        );
    }

    public void replaceChunks(String documentId, String workspaceId, List<String> chunks, String now) {
        jdbcTemplate.update("""
                DELETE FROM knowledge_chunks
                WHERE document_id = ?
                """, documentId);
        for (var index = 0; index < chunks.size(); index++) {
            jdbcTemplate.update("""
                    INSERT INTO knowledge_chunks(id, document_id, workspace_id, chunk_index, content, created_at)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    "kch_" + UUID.randomUUID(),
                    documentId,
                    workspaceId,
                    index,
                    chunks.get(index),
                    now
            );
        }
    }

    public List<KnowledgeDocumentSummary> listDocuments(String workspaceId) {
        return jdbcTemplate.query("""
                SELECT id, workspace_id, channel_id, file_name, content_type, size_bytes,
                       summary, snippet_count, status, created_at
                FROM knowledge_documents
                WHERE workspace_id = ?
                ORDER BY created_at DESC
                """, DOCUMENT_MAPPER, workspaceId);
    }

    public Optional<KnowledgeDocumentSummary> findDocument(String documentId) {
        return jdbcTemplate.query("""
                SELECT id, workspace_id, channel_id, file_name, content_type, size_bytes,
                       summary, snippet_count, status, created_at
                FROM knowledge_documents
                WHERE id = ?
                """, DOCUMENT_MAPPER, documentId).stream().findFirst();
    }

    public List<KnowledgeChunk> listChunks(String workspaceId, int limit) {
        return jdbcTemplate.query("""
                SELECT kc.document_id, kd.file_name, kd.channel_id, kc.content, kc.chunk_index,
                       kc.created_at AS chunk_created_at, kd.created_at AS document_created_at
                FROM knowledge_chunks kc
                JOIN knowledge_documents kd ON kd.id = kc.document_id
                WHERE kc.workspace_id = ?
                ORDER BY kd.created_at DESC, kc.chunk_index ASC
                LIMIT ?
                """, CHUNK_MAPPER, workspaceId, limit);
    }

    private static KnowledgeDocumentSummary mapDocument(ResultSet rs, int rowNum) throws SQLException {
        return new KnowledgeDocumentSummary(
                rs.getString("id"),
                rs.getString("workspace_id"),
                rs.getString("channel_id"),
                rs.getString("file_name"),
                rs.getString("content_type"),
                rs.getLong("size_bytes"),
                rs.getString("summary"),
                rs.getInt("snippet_count"),
                rs.getString("status"),
                rs.getString("created_at")
        );
    }

    private static KnowledgeChunk mapChunk(ResultSet rs, int rowNum) throws SQLException {
        return new KnowledgeChunk(
                rs.getString("document_id"),
                rs.getString("file_name"),
                rs.getString("channel_id"),
                rs.getString("content"),
                rs.getInt("chunk_index"),
                rs.getString("chunk_created_at"),
                rs.getString("document_created_at")
        );
    }
}
