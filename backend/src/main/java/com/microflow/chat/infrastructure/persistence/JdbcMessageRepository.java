package com.microflow.chat.infrastructure.persistence;

import com.microflow.chat.domain.model.ChatMessage;
import com.microflow.chat.infrastructure.encryption.CipherService;
import com.microflow.common.crypto.EncryptedPayload;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcMessageRepository {

    private final JdbcTemplate jdbcTemplate;
    private final CipherService cipherService;
    private final Clock clock;

    public JdbcMessageRepository(JdbcTemplate jdbcTemplate, CipherService cipherService, Clock clock) {
        this.jdbcTemplate = jdbcTemplate;
        this.cipherService = cipherService;
        this.clock = clock;
    }

    public ChatMessage saveUserMessage(String workspaceId, String channelId, String senderUserId, String content) {
        return saveMessage(workspaceId, channelId, "USER", senderUserId, null, content);
    }

    public ChatMessage saveAgentMessage(String workspaceId, String channelId, String agentKey, String content) {
        return saveMessage(workspaceId, channelId, "AGENT", null, agentKey, content);
    }

    public List<ChatMessage> findByChannel(String channelId, int limit) {
        return jdbcTemplate.query("""
                SELECT id, workspace_id, channel_id, sender_type, sender_user_id, sender_agent_key,
                       ciphertext, iv, key_version, created_at
                FROM messages
                WHERE channel_id = ?
                ORDER BY created_at ASC
                LIMIT ?
                """, new ChatMessageRowMapper(cipherService), channelId, limit);
    }

    public void saveMention(String messageId, String agentKey) {
        jdbcTemplate.update("""
                INSERT INTO message_mentions(id, message_id, mention_type, target_ref, created_at)
                VALUES (?, ?, 'AGENT', ?, ?)
                """, "mm_" + UUID.randomUUID(), messageId, agentKey, Instant.now(clock).toString());
    }

    private ChatMessage saveMessage(
            String workspaceId,
            String channelId,
            String senderType,
            String senderUserId,
            String senderAgentKey,
            String content
    ) {
        var id = "msg_" + UUID.randomUUID();
        var encrypted = cipherService.encrypt(content);
        var createdAt = Instant.now(clock).toString();
        jdbcTemplate.update("""
                INSERT INTO messages(
                    id, workspace_id, channel_id, sender_type, sender_user_id, sender_agent_key,
                    message_type, ciphertext, iv, auth_tag, key_version, reply_to_message_id, created_at, edited_at
                )
                VALUES (?, ?, ?, ?, ?, ?, 'TEXT', ?, ?, NULL, ?, NULL, ?, NULL)
                """,
                id, workspaceId, channelId, senderType, senderUserId, senderAgentKey,
                encrypted.ciphertext(), encrypted.iv(), encrypted.keyVersion(), createdAt);
        return new ChatMessage(
                id,
                workspaceId,
                channelId,
                senderType.equals("AGENT") ? "agent:" + senderAgentKey : senderUserId,
                content,
                Instant.parse(createdAt)
        );
    }

    private record ChatMessageRowMapper(CipherService cipherService) implements RowMapper<ChatMessage> {
        @Override
        public ChatMessage mapRow(ResultSet rs, int rowNum) throws SQLException {
            var senderType = rs.getString("sender_type");
            var senderUserId = senderType.equals("AGENT")
                    ? "agent:" + rs.getString("sender_agent_key")
                    : rs.getString("sender_user_id");
            var encryptedPayload = new EncryptedPayload(
                    rs.getBytes("ciphertext"),
                    rs.getBytes("iv"),
                    rs.getInt("key_version")
            );
            return new ChatMessage(
                    rs.getString("id"),
                    rs.getString("workspace_id"),
                    rs.getString("channel_id"),
                    senderUserId,
                    cipherService.decrypt(encryptedPayload),
                    Instant.parse(rs.getString("created_at"))
            );
        }
    }
}

