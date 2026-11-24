package com.microflow.task.infrastructure.persistence;

import com.microflow.task.domain.model.TaskDecision;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import com.microflow.common.jdbc.DataIntegrityViolationException;
import com.microflow.common.jdbc.JdbcTemplate;
import com.microflow.common.jdbc.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcTaskDecisionRepository {

    private static final RowMapper<TaskDecision> DECISION_MAPPER =
            JdbcTaskDecisionRepository::mapDecision;

    private static final String DECISION_SELECT = """
            SELECT d.id, d.workspace_id, d.task_id, d.sequence_no, d.supersedes_decision_id,
                   d.summary, d.rationale, d.alternatives_considered,
                   d.decided_by_user_id, u.display_name AS decided_by_display_name, d.created_at
            FROM task_decisions d
            JOIN users u ON u.id = d.decided_by_user_id
            """;

    private final JdbcTemplate jdbcTemplate;
    private final Clock clock;

    public JdbcTaskDecisionRepository(JdbcTemplate jdbcTemplate, Clock clock) {
        this.jdbcTemplate = jdbcTemplate;
        this.clock = clock;
    }

    public List<TaskDecision> findByTask(String workspaceId, String taskId) {
        return jdbcTemplate.query(
                DECISION_SELECT + " WHERE d.workspace_id = ? AND d.task_id = ?"
                        + " ORDER BY d.sequence_no DESC",
                DECISION_MAPPER, workspaceId, taskId);
    }

    public Optional<TaskDecision> findDecision(String workspaceId, String decisionId) {
        return jdbcTemplate.query(
                DECISION_SELECT + " WHERE d.workspace_id = ? AND d.id = ?",
                DECISION_MAPPER, workspaceId, decisionId).stream().findFirst();
    }

    public Optional<TaskDecision> findLatest(String workspaceId, String taskId) {
        return jdbcTemplate.query(
                DECISION_SELECT + " WHERE d.workspace_id = ? AND d.task_id = ?"
                        + " ORDER BY d.sequence_no DESC LIMIT 1",
                DECISION_MAPPER, workspaceId, taskId).stream().findFirst();
    }

    public int nextSequenceNo(String workspaceId, String taskId) {
        Integer max = jdbcTemplate.queryForObject("""
                SELECT COALESCE(MAX(sequence_no), 0)
                FROM task_decisions
                WHERE workspace_id = ? AND task_id = ?
                """, Integer.class, workspaceId, taskId);
        return max == null ? 1 : max + 1;
    }

    /**
     * Appends a decision, retrying once when two writers pick the same
     * {@code sequence_no}. The UNIQUE(task_id, sequence_no) constraint is the
     * arbiter: the loser of the race re-reads the next number and tries again,
     * so a concurrent pair produces two ordered records instead of a 500.
     *
     * @throws com.microflow.common.jdbc.DataIntegrityViolationException if the
     *     collision persists after the retry
     */
    public String insert(
            String workspaceId,
            String taskId,
            String supersedesDecisionId,
            String summary,
            String rationale,
            String alternativesConsidered,
            String decidedByUserId
    ) {
        try {
            return insertOnce(workspaceId, taskId, supersedesDecisionId, summary,
                    rationale, alternativesConsidered, decidedByUserId);
        } catch (DataIntegrityViolationException firstCollision) {
            return insertOnce(workspaceId, taskId, supersedesDecisionId, summary,
                    rationale, alternativesConsidered, decidedByUserId);
        }
    }

    private String insertOnce(
            String workspaceId,
            String taskId,
            String supersedesDecisionId,
            String summary,
            String rationale,
            String alternativesConsidered,
            String decidedByUserId
    ) {
        var decisionId = "dec_" + UUID.randomUUID();
        var sequenceNo = nextSequenceNo(workspaceId, taskId);
        jdbcTemplate.update("""
                INSERT INTO task_decisions(id, workspace_id, task_id, sequence_no,
                                           supersedes_decision_id, summary, rationale,
                                           alternatives_considered, decided_by_user_id, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                decisionId, workspaceId, taskId, sequenceNo, supersedesDecisionId,
                summary, rationale, alternativesConsidered, decidedByUserId,
                Instant.now(clock).toString());
        return decisionId;
    }

    private static TaskDecision mapDecision(ResultSet rs, int rowNum) throws SQLException {
        var createdAt = rs.getString("created_at");
        return new TaskDecision(
                rs.getString("id"),
                rs.getString("workspace_id"),
                rs.getString("task_id"),
                rs.getInt("sequence_no"),
                rs.getString("supersedes_decision_id"),
                rs.getString("summary"),
                rs.getString("rationale"),
                rs.getString("alternatives_considered"),
                rs.getString("decided_by_user_id"),
                rs.getString("decided_by_display_name"),
                createdAt == null || createdAt.isBlank() ? null : Instant.parse(createdAt)
        );
    }
}
