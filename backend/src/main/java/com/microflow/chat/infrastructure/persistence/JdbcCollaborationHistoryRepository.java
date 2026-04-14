package com.microflow.chat.infrastructure.persistence;

import com.microflow.chat.domain.model.CollaborationEventLog;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcCollaborationHistoryRepository {

    private static final RowMapper<CollaborationEventLog> EVENT_MAPPER = JdbcCollaborationHistoryRepository::mapEvent;

    private final JdbcTemplate jdbcTemplate;

    public JdbcCollaborationHistoryRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
        ensureSummaryColumns();
    }

    public void appendEvent(
            String id,
            String workspaceId,
            String channelId,
            String collaborationId,
            String triggerMessageId,
            String eventType,
            String status,
            String stage,
            String agentKey,
            String reason,
            String agentKeys,
            String trigger,
            int round,
            int maxRounds,
            String detail,
            String createdAt
    ) {
        jdbcTemplate.update(connection -> {
            PreparedStatement statement = connection.prepareStatement("""
                    INSERT INTO collaboration_events(
                        id, workspace_id, channel_id, collaboration_id, trigger_message_id,
                        event_type, status, stage, agent_key, reason, agent_keys,
                        trigger_token, round, max_rounds, detail, created_at
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """);
            statement.setString(1, id);
            statement.setString(2, workspaceId);
            statement.setString(3, channelId);
            statement.setString(4, collaborationId);
            setNullableText(statement, 5, triggerMessageId);
            statement.setString(6, eventType);
            statement.setString(7, status);
            setNullableText(statement, 8, stage);
            setNullableText(statement, 9, agentKey);
            setNullableText(statement, 10, reason);
            setNullableText(statement, 11, agentKeys);
            setNullableText(statement, 12, trigger);
            statement.setInt(13, round);
            statement.setInt(14, maxRounds);
            setNullableText(statement, 15, detail);
            statement.setString(16, createdAt);
            return statement;
        });
    }

    public List<CollaborationEventLog> listByChannel(String channelId, int limit) {
        return jdbcTemplate.query("""
                SELECT id, workspace_id, channel_id, collaboration_id, trigger_message_id,
                       event_type, status, stage, agent_key, reason, agent_keys,
                       trigger_token, round, max_rounds, detail, created_at
                FROM collaboration_events
                WHERE channel_id = ?
                ORDER BY created_at DESC
                LIMIT ?
                """, EVENT_MAPPER, channelId, limit);
    }

    public List<String> listRecentCollaborationIds(String channelId, int limit) {
        return jdbcTemplate.queryForList("""
                SELECT collaboration_id
                FROM collaboration_events
                WHERE channel_id = ?
                GROUP BY collaboration_id
                ORDER BY MAX(created_at) DESC
                LIMIT ?
                """, String.class, channelId, limit);
    }

    public List<CollaborationEventLog> listByChannelAndCollaborationIds(String channelId, List<String> collaborationIds) {
        if (collaborationIds.isEmpty()) {
            return List.of();
        }
        var placeholders = String.join(", ", java.util.Collections.nCopies(collaborationIds.size(), "?"));
        var parameters = new ArrayList<Object>();
        parameters.add(channelId);
        parameters.addAll(collaborationIds);
        return jdbcTemplate.query("""
                SELECT id, workspace_id, channel_id, collaboration_id, trigger_message_id,
                       event_type, status, stage, agent_key, reason, agent_keys,
                       trigger_token, round, max_rounds, detail, created_at
                FROM collaboration_events
                WHERE channel_id = ?
                  AND collaboration_id IN (""" + placeholders + ") " +
                "ORDER BY created_at ASC",
                EVENT_MAPPER,
                parameters.toArray()
        );
    }

    private static CollaborationEventLog mapEvent(ResultSet rs, int rowNum) throws SQLException {
        return new CollaborationEventLog(
                rs.getString("id"),
                rs.getString("workspace_id"),
                rs.getString("channel_id"),
                rs.getString("collaboration_id"),
                rs.getString("trigger_message_id"),
                rs.getString("event_type"),
                rs.getString("status"),
                rs.getString("stage"),
                rs.getString("agent_key"),
                rs.getString("reason"),
                rs.getString("agent_keys"),
                rs.getString("trigger_token"),
                rs.getInt("round"),
                rs.getInt("max_rounds"),
                rs.getString("detail"),
                rs.getString("created_at")
        );
    }

    private void ensureSummaryColumns() {
        var knownColumns = new HashSet<String>();
        jdbcTemplate.query("PRAGMA table_info(collaboration_events)", rs -> {
            knownColumns.add(rs.getString("name"));
        });
        addColumnIfMissing(knownColumns, "trigger_message_id", "TEXT");
        addColumnIfMissing(knownColumns, "reason", "TEXT");
        addColumnIfMissing(knownColumns, "agent_keys", "TEXT");
    }

    private void addColumnIfMissing(HashSet<String> knownColumns, String columnName, String columnType) {
        if (knownColumns.contains(columnName)) {
            return;
        }
        jdbcTemplate.execute("ALTER TABLE collaboration_events ADD COLUMN " + columnName + " " + columnType);
        knownColumns.add(columnName);
    }

    private static void setNullableText(PreparedStatement statement, int parameterIndex, String value) throws SQLException {
        if (value == null) {
            statement.setNull(parameterIndex, Types.VARCHAR);
            return;
        }
        statement.setString(parameterIndex, value);
    }
}
