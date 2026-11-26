package com.microflow.agent.runtime.infrastructure.persistence;

import com.microflow.agent.runtime.domain.gateway.ProviderCapability;
import com.microflow.agent.runtime.domain.gateway.TurnMessage;
import com.microflow.agent.runtime.domain.model.AgentApproval;
import com.microflow.agent.runtime.domain.model.AgentApprovalStatus;
import com.microflow.agent.runtime.domain.model.AgentArtifact;
import com.microflow.agent.runtime.domain.model.AgentContextSource;
import com.microflow.agent.runtime.domain.model.AgentRunEvent;
import com.microflow.agent.runtime.domain.model.AgentRunSession;
import com.microflow.agent.runtime.domain.model.AgentRunStatus;
import com.microflow.agent.runtime.domain.model.AgentRunStep;
import com.microflow.agent.runtime.domain.model.AgentToolInvocation;
import com.microflow.agent.runtime.domain.model.ToolCallRequest;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import com.microflow.common.jdbc.JdbcTemplate;
import com.microflow.common.jdbc.RowMapper;
import org.springframework.stereotype.Repository;

/**
 * Persistence for the agent runtime.
 *
 * <p>Two invariants live here rather than in the service:
 *
 * <ul>
 *   <li>event and step sequences are allocated inside the insert so a gap or a
 *       duplicate is impossible within a single process, and the unique index
 *       catches a second writer;</li>
 *   <li>status changes are guarded by the expected previous status, so a cancel
 *       racing an approval cannot silently overwrite the winner.</li>
 * </ul>
 */
@Repository
public class JdbcAgentRuntimeRepository {

    private final JdbcTemplate jdbcTemplate;
    private final Clock clock;
    private final ObjectMapper objectMapper;

    public JdbcAgentRuntimeRepository(JdbcTemplate jdbcTemplate, Clock clock, ObjectMapper objectMapper) {
        this.jdbcTemplate = jdbcTemplate;
        this.clock = clock;
        this.objectMapper = objectMapper;
    }

    // ------------------------------------------------------------------ sessions

    public void insertSession(AgentRunSession session) {
        jdbcTemplate.update("""
                INSERT INTO agent_run_sessions(
                    id, workspace_id, task_id, channel_id, trigger_message_id, initiator_user_id,
                    agent_key, run_kind, status, goal, context_summary, error_message,
                    interruption_state, resumed_from_session_id, step_count, approval_wait_count,
                    attempt_count, created_at, started_at, finished_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                session.id(), session.workspaceId(), session.taskId(), session.channelId(),
                session.triggerMessageId(), session.initiatorUserId(), session.agentKey(),
                session.runKind(), session.status().name(), session.goal(),
                session.contextSummary(), session.errorMessage(),
                session.interruptionState() == null ? "NONE" : session.interruptionState(),
                session.resumedFromSessionId(), session.stepCount(), session.approvalWaitCount(),
                session.attemptCount(), session.createdAt(), session.startedAt(),
                session.finishedAt(), session.updatedAt());
    }

    public Optional<AgentRunSession> findSession(String sessionId) {
        return jdbcTemplate.query(
                "SELECT * FROM agent_run_sessions WHERE id = ?",
                SESSION_MAPPER, sessionId
        ).stream().findFirst();
    }

    public List<AgentRunSession> listSessions(
            String workspaceId,
            String taskId,
            String status,
            int limit
    ) {
        var sql = new StringBuilder("SELECT * FROM agent_run_sessions WHERE workspace_id = ?");
        var args = new java.util.ArrayList<Object>();
        args.add(workspaceId);
        if (taskId != null && !taskId.isBlank()) {
            sql.append(" AND task_id = ?");
            args.add(taskId);
        }
        if (status != null && !status.isBlank()) {
            sql.append(" AND status = ?");
            args.add(status.trim().toUpperCase(java.util.Locale.ROOT));
        }
        sql.append("""
                 ORDER BY CASE status
                    WHEN 'WAITING_APPROVAL' THEN 0
                    WHEN 'RUNNING' THEN 1
                    WHEN 'CONTEXT_BUILDING' THEN 2
                    WHEN 'QUEUED' THEN 3
                    ELSE 4 END, created_at DESC, id DESC LIMIT ?
                """);
        args.add(Math.max(1, limit));
        return jdbcTemplate.query(sql.toString(), SESSION_MAPPER, args.toArray());
    }

    public List<AgentRunSession> listActiveSessions(String workspaceId, String taskId, String afterId, int limit) {
        var sql = new StringBuilder("""
                SELECT * FROM agent_run_sessions WHERE workspace_id = ?
                AND status IN ('QUEUED', 'CONTEXT_BUILDING', 'RUNNING', 'WAITING_APPROVAL')
                """);
        var args = new java.util.ArrayList<Object>();
        args.add(workspaceId);
        if (taskId != null && !taskId.isBlank()) { sql.append(" AND task_id = ?"); args.add(taskId); }
        if (afterId != null && !afterId.isBlank()) { sql.append(" AND id > ?"); args.add(afterId); }
        sql.append(" ORDER BY id ASC LIMIT ?");
        args.add(limit);
        return jdbcTemplate.query(sql.toString(), SESSION_MAPPER, args.toArray());
    }

    public List<AgentRunSession> listSessionsByStatus(String status, int limit) {
        return listSessionsByStatus(status, null, limit);
    }

    public List<AgentRunSession> listSessionsByStatus(String status, String afterId, int limit) {
        return jdbcTemplate.query("""
                SELECT * FROM agent_run_sessions WHERE status = ? AND id > ?
                ORDER BY id ASC LIMIT ?
                """, SESSION_MAPPER, status, afterId == null ? "" : afterId, Math.max(1, limit));
    }

    public boolean updateStatus(
            String sessionId,
            AgentRunStatus from,
            AgentRunStatus to,
            String errorMessage,
            String startedAt,
            String finishedAt
    ) {
        return jdbcTemplate.update("""
                UPDATE agent_run_sessions
                SET status = ?,
                    error_message = COALESCE(?, error_message),
                    started_at = COALESCE(?, started_at),
                    finished_at = COALESCE(?, finished_at),
                    updated_at = ?
                WHERE id = ? AND status = ?
                """,
                to.name(), errorMessage, startedAt, finishedAt, now(), sessionId, from.name()) > 0;
    }

    public void setContextSummary(String sessionId, String summary, int stepCount) {
        jdbcTemplate.update("""
                UPDATE agent_run_sessions
                SET context_summary = ?, step_count = ?, updated_at = ?
                WHERE id = ?
                """, summary, stepCount, now(), sessionId);
    }

    public boolean markInterrupted(String sessionId, String errorMessage) {
        // Freeze possible external effects before making the run retryable. If
        // recovery itself is interrupted, the next recovery sees UNKNOWN again.
        jdbcTemplate.update("""
                UPDATE agent_tool_invocations
                SET status = CASE WHEN risk_level IN ('EXTERNAL_WRITE', 'DESTRUCTIVE')
                                  THEN 'UNKNOWN' ELSE 'FAILED' END,
                    error_message = ?, finished_at = ?
                WHERE session_id = ? AND status = 'APPROVED'
                AND EXISTS (SELECT 1 FROM agent_run_sessions
                            WHERE id = ? AND status IN ('CONTEXT_BUILDING', 'RUNNING'))
                """, errorMessage, now(), sessionId, sessionId);
        jdbcTemplate.update("""
                UPDATE agent_run_steps SET status = 'FAILED', finished_at = ?
                WHERE session_id = ? AND finished_at IS NULL
                AND EXISTS (SELECT 1 FROM agent_run_sessions
                            WHERE id = ? AND status IN ('CONTEXT_BUILDING', 'RUNNING'))
                """, now(), sessionId, sessionId);
        return jdbcTemplate.update("""
                UPDATE agent_run_sessions
                SET status = 'FAILED',
                    interruption_state = 'INTERRUPTED',
                    error_message = ?,
                    finished_at = ?,
                    updated_at = ?
                WHERE id = ? AND status IN ('CONTEXT_BUILDING', 'RUNNING')
                """, errorMessage, now(), now(), sessionId) > 0;
    }

    public boolean resetForRetry(String sessionId) {
        return jdbcTemplate.update("""
                UPDATE agent_run_sessions
                SET status = 'QUEUED',
                    error_message = NULL,
                    interruption_state = 'NONE',
                    context_summary = NULL,
                    started_at = NULL,
                    finished_at = NULL,
                    attempt_count = attempt_count + 1,
                    updated_at = ?
                WHERE id = ? AND status = 'FAILED'
                AND NOT EXISTS (SELECT 1 FROM agent_tool_invocations
                                WHERE session_id = ? AND status = 'UNKNOWN')
                """, now(), sessionId, sessionId) > 0;
    }

    /** The execution admission point: only one still-authorized worker wins. */
    public boolean claimInvocation(String invocationId) {
        return jdbcTemplate.update("""
                UPDATE agent_tool_invocations SET status = 'APPROVED'
                WHERE id = ? AND status IN ('PENDING', 'AWAITING_APPROVAL')
                AND EXISTS (SELECT 1 FROM agent_run_sessions s
                            WHERE s.id = agent_tool_invocations.session_id AND s.status = 'RUNNING')
                AND (approval_id IS NULL OR EXISTS (
                    SELECT 1 FROM agent_approvals a
                    WHERE a.id = agent_tool_invocations.approval_id
                    AND a.session_id = agent_tool_invocations.session_id AND a.status = 'APPROVED'))
                """, invocationId) > 0;
    }

    // -------------------------------------------------------------------- events

    /** Appends one event and returns its per-run sequence number. */
    public synchronized long appendEvent(String sessionId, String workspaceId, String type, String payloadJson) {
        var eventId = "rev_" + java.util.UUID.randomUUID();
        jdbcTemplate.update("""
                INSERT INTO agent_run_events(id, session_id, workspace_id, seq, event_type, payload_json, created_at)
                SELECT ?, ?, ?, COALESCE(MAX(seq), 0) + 1, ?, ?, ?
                FROM agent_run_events
                WHERE session_id = ?
                """, eventId, sessionId, workspaceId, type, payloadJson, now(), sessionId);
        Long seq = jdbcTemplate.queryForObject(
                "SELECT seq FROM agent_run_events WHERE id = ?", Long.class, eventId);
        return seq == null ? 0L : seq;
    }

    public List<AgentRunEvent> listEvents(String sessionId, long afterSeq, int limit) {
        return jdbcTemplate.query("""
                SELECT id, session_id, workspace_id, seq, event_type, payload_json, created_at
                FROM agent_run_events
                WHERE session_id = ? AND seq > ?
                ORDER BY seq ASC
                LIMIT ?
                """, EVENT_MAPPER, sessionId, afterSeq, Math.max(1, limit));
    }

    // --------------------------------------------------------------------- steps

    public synchronized AgentRunStep createStep(
            String sessionId,
            String stepKind,
            String status,
            String agentKey,
            String title,
            String detail
    ) {
        var stepId = "stp_" + java.util.UUID.randomUUID();
        jdbcTemplate.update("""
                INSERT INTO agent_run_steps(id, session_id, seq, step_kind, status, agent_key, title, detail, started_at)
                SELECT ?, ?, COALESCE(MAX(seq), 0) + 1, ?, ?, ?, ?, ?, ?
                FROM agent_run_steps
                WHERE session_id = ?
                """, stepId, sessionId, stepKind, status, agentKey, title, detail, now(), sessionId);
        var step = jdbcTemplate.query(
                "SELECT * FROM agent_run_steps WHERE id = ?", STEP_MAPPER, stepId
        ).stream().findFirst().orElseThrow();
        bumpStepCount(sessionId);
        return step;
    }

    public void finishStep(String stepId, String status, String detail) {
        jdbcTemplate.update("""
                UPDATE agent_run_steps
                SET status = ?, detail = COALESCE(?, detail), finished_at = ?
                WHERE id = ?
                """, status, detail, now(), stepId);
    }

    public List<AgentRunStep> listSteps(String sessionId) {
        return jdbcTemplate.query(
                "SELECT * FROM agent_run_steps WHERE session_id = ? ORDER BY seq ASC",
                STEP_MAPPER, sessionId);
    }

    private void bumpStepCount(String sessionId) {
        jdbcTemplate.update("""
                UPDATE agent_run_sessions SET step_count = step_count + 1, updated_at = ? WHERE id = ?
                """, now(), sessionId);
    }

    // ------------------------------------------------------------------ messages

    public synchronized void appendMessage(String sessionId, TurnMessage message) {
        jdbcTemplate.update("""
                INSERT INTO agent_run_messages(id, session_id, seq, role, content, tool_calls_json, tool_call_id, created_at)
                SELECT ?, ?, COALESCE(MAX(seq), 0) + 1, ?, ?, ?, ?, ?
                FROM agent_run_messages
                WHERE session_id = ?
                """, "msg_" + java.util.UUID.randomUUID(), sessionId, message.role(), message.content(),
                writeJson(message.toolCalls()), message.toolCallId(), now(), sessionId);
    }

    public List<TurnMessage> listMessages(String sessionId) {
        return jdbcTemplate.query("""
                SELECT role, content, tool_calls_json, tool_call_id
                FROM agent_run_messages
                WHERE session_id = ?
                ORDER BY seq ASC
                """, (rs, rowNum) -> new TurnMessage(
                rs.getString("role"),
                rs.getString("content"),
                readToolCalls(rs.getString("tool_calls_json")),
                rs.getString("tool_call_id")
        ), sessionId);
    }

    // ----------------------------------------------------------- context sources

    public void replaceContextSources(String sessionId, String workspaceId, List<AgentContextSource> sources) {
        jdbcTemplate.update("DELETE FROM agent_context_sources WHERE session_id = ?", sessionId);
        for (var source : sources) {
            jdbcTemplate.update("""
                    INSERT INTO agent_context_sources(
                        id, session_id, workspace_id, source_type, ref_id, label, excerpt, included, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, source.id(), sessionId, workspaceId, source.sourceType(), source.refId(),
                    source.label(), source.excerpt(), source.included() ? 1 : 0, now());
        }
    }

    public List<AgentContextSource> listContextSources(String sessionId) {
        return jdbcTemplate.query("""
                SELECT id, session_id, workspace_id, source_type, ref_id, label, excerpt, included, created_at
                FROM agent_context_sources
                WHERE session_id = ?
                ORDER BY created_at ASC, id ASC
                """, (rs, rowNum) -> new AgentContextSource(
                rs.getString("id"),
                rs.getString("session_id"),
                rs.getString("workspace_id"),
                rs.getString("source_type"),
                rs.getString("ref_id"),
                rs.getString("label"),
                rs.getString("excerpt"),
                rs.getInt("included") == 1,
                rs.getString("created_at")
        ), sessionId);
    }

    // ----------------------------------------------------------------- approvals

    public void insertApproval(AgentApproval approval) {
        jdbcTemplate.update("""
                INSERT INTO agent_approvals(
                    id, session_id, workspace_id, step_id, tool_key, action, target_resource,
                    risk_level, impact_summary, input_json, status, decided_by_user_id,
                    decision_note, created_at, decided_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, approval.id(), approval.sessionId(), approval.workspaceId(), approval.stepId(),
                approval.toolKey(), approval.action(), approval.targetResource(), approval.riskLevel(),
                approval.impactSummary(), approval.inputJson(), approval.status().name(),
                approval.decidedByUserId(), approval.decisionNote(), approval.createdAt(),
                approval.decidedAt());
        jdbcTemplate.update("""
                UPDATE agent_run_sessions SET approval_wait_count = approval_wait_count + 1, updated_at = ?
                WHERE id = ?
                """, now(), approval.sessionId());
    }

    public Optional<AgentApproval> findApproval(String approvalId) {
        return jdbcTemplate.query(
                "SELECT * FROM agent_approvals WHERE id = ?", APPROVAL_MAPPER, approvalId
        ).stream().findFirst();
    }

    public List<AgentApproval> listApprovals(String sessionId, String status) {
        if (status == null || status.isBlank()) {
            return jdbcTemplate.query(
                    "SELECT * FROM agent_approvals WHERE session_id = ? ORDER BY created_at ASC",
                    APPROVAL_MAPPER, sessionId);
        }
        return jdbcTemplate.query(
                "SELECT * FROM agent_approvals WHERE session_id = ? AND status = ? ORDER BY created_at ASC",
                APPROVAL_MAPPER, sessionId, status.trim().toUpperCase(java.util.Locale.ROOT));
    }

    public Optional<AgentApproval> findPendingApproval(String sessionId) {
        return jdbcTemplate.query("""
                SELECT * FROM agent_approvals
                WHERE session_id = ? AND status = 'PENDING'
                ORDER BY created_at DESC LIMIT 1
                """, APPROVAL_MAPPER, sessionId).stream().findFirst();
    }

    /** Pending approval id per run, for list views that must not issue one query per row. */
    public java.util.Map<String, String> pendingApprovalIds(String workspaceId) {
        var result = new java.util.LinkedHashMap<String, String>();
        var rows = jdbcTemplate.queryForList("""
                SELECT session_id, id FROM agent_approvals
                WHERE workspace_id = ? AND status = 'PENDING'
                ORDER BY created_at ASC
                """, workspaceId);
        for (var row : rows) {
            result.putIfAbsent((String) row.get("session_id"), (String) row.get("id"));
        }
        return result;
    }

    public int countPendingApprovals(String workspaceId) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT COUNT(1) FROM agent_approvals WHERE workspace_id = ? AND status = 'PENDING'
                """, Integer.class, workspaceId);
        return count == null ? 0 : count;
    }

    public boolean decideApproval(
            String approvalId,
            AgentApprovalStatus to,
            String decidedByUserId,
            String note
    ) {
        return jdbcTemplate.update("""
                UPDATE agent_approvals
                SET status = ?, decided_by_user_id = ?, decision_note = ?, decided_at = ?
                WHERE id = ? AND status = 'PENDING'
                """, to.name(), decidedByUserId, note, now(), approvalId) > 0;
    }

    public void cancelPendingApprovals(String sessionId) {
        jdbcTemplate.update("""
                UPDATE agent_approvals
                SET status = 'CANCELLED', decided_at = ?
                WHERE session_id = ? AND status = 'PENDING'
                """, now(), sessionId);
        jdbcTemplate.update("""
                UPDATE agent_tool_invocations
                SET status = 'CANCELLED', error_message = 'Run cancelled', finished_at = ?
                WHERE session_id = ? AND status IN ('PENDING', 'AWAITING_APPROVAL')
                """, now(), sessionId);
        jdbcTemplate.update("""
                UPDATE agent_run_steps
                SET status = 'CANCELLED', finished_at = ?
                WHERE session_id = ? AND finished_at IS NULL
                """, now(), sessionId);
    }

    // ----------------------------------------------------------------- artifacts

    public void insertArtifact(AgentArtifact artifact) {
        jdbcTemplate.update("""
                INSERT INTO agent_artifacts(
                    id, session_id, workspace_id, artifact_kind, title, summary, content_text, uri, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, artifact.id(), artifact.sessionId(), artifact.workspaceId(),
                artifact.artifactKind(), artifact.title(), artifact.summary(),
                artifact.contentText(), artifact.uri(), now());
    }

    public List<AgentArtifact> listArtifacts(String sessionId) {
        return jdbcTemplate.query("""
                SELECT id, session_id, workspace_id, artifact_kind, title, summary, content_text, uri, created_at
                FROM agent_artifacts
                WHERE session_id = ?
                ORDER BY created_at ASC
                """, (rs, rowNum) -> new AgentArtifact(
                rs.getString("id"),
                rs.getString("session_id"),
                rs.getString("workspace_id"),
                rs.getString("artifact_kind"),
                rs.getString("title"),
                rs.getString("summary"),
                rs.getString("content_text"),
                rs.getString("uri"),
                rs.getString("created_at")
        ), sessionId);
    }

    // --------------------------------------------------------------- invocations

    public void insertInvocation(AgentToolInvocation invocation) {
        jdbcTemplate.update("""
                INSERT INTO agent_tool_invocations(
                    id, session_id, workspace_id, step_id, tool_key, idempotency_key, status,
                    risk_level, input_json, output_json, approval_id, error_message,
                    attempt_count, created_at, finished_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, invocation.id(), invocation.sessionId(), invocation.workspaceId(),
                invocation.stepId(), invocation.toolKey(), invocation.idempotencyKey(),
                invocation.status().name(), invocation.riskLevel(), invocation.inputJson(),
                invocation.outputJson(), invocation.approvalId(), invocation.errorMessage(),
                invocation.attemptCount(), invocation.createdAt(), invocation.finishedAt());
    }

    public Optional<AgentToolInvocation> findInvocation(String invocationId) {
        return jdbcTemplate.query(
                "SELECT * FROM agent_tool_invocations WHERE id = ?", INVOCATION_MAPPER, invocationId
        ).stream().findFirst();
    }

    public Optional<AgentToolInvocation> findInvocationByKey(String sessionId, String idempotencyKey) {
        return jdbcTemplate.query("""
                SELECT * FROM agent_tool_invocations
                WHERE session_id = ? AND idempotency_key = ?
                LIMIT 1
                """, INVOCATION_MAPPER, sessionId, idempotencyKey).stream().findFirst();
    }

    public List<AgentToolInvocation> listInvocations(String sessionId) {
        return jdbcTemplate.query(
                "SELECT * FROM agent_tool_invocations WHERE session_id = ? ORDER BY created_at ASC",
                INVOCATION_MAPPER, sessionId);
    }

    public void updateInvocation(
            String invocationId,
            AgentToolInvocation.Status status,
            String outputJson,
            String errorMessage,
            boolean incrementAttempt
    ) {
        jdbcTemplate.update("""
                UPDATE agent_tool_invocations
                SET status = ?,
                    output_json = COALESCE(?, output_json),
                    error_message = ?,
                    attempt_count = attempt_count + CASE WHEN ? THEN 1 ELSE 0 END,
                    finished_at = CASE WHEN ? THEN ? ELSE finished_at END
                WHERE id = ?
                """, status.name(), outputJson, errorMessage, incrementAttempt,
                status.isSettled(), now(), invocationId);
    }

    public boolean hasUnknownInvocation(String sessionId) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT COUNT(1) FROM agent_tool_invocations
                WHERE session_id = ? AND status = 'UNKNOWN'
                """, Integer.class, sessionId);
        return count != null && count > 0;
    }

    // -------------------------------------------------------------- capabilities

    public Optional<ProviderCapability> findCapability(String workspaceId, String agentKey) {
        return jdbcTemplate.query("""
                SELECT supports_tool_calls, detail, detected_at
                FROM agent_provider_capabilities
                WHERE workspace_id = ? AND agent_key = ?
                """, (rs, rowNum) -> new ProviderCapability(
                rs.getInt("supports_tool_calls") == 1,
                rs.getString("detail"),
                rs.getString("detected_at")
        ), workspaceId, agentKey).stream().findFirst();
    }

    public void upsertCapability(String workspaceId, String agentKey, ProviderCapability capability) {
        jdbcTemplate.update("""
                INSERT INTO agent_provider_capabilities(
                    workspace_id, agent_key, supports_tool_calls, detail, detected_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(workspace_id, agent_key) DO UPDATE SET
                    supports_tool_calls = excluded.supports_tool_calls,
                    detail = excluded.detail,
                    detected_at = excluded.detected_at
                """, workspaceId, agentKey, capability.supportsToolCalls() ? 1 : 0,
                capability.detail(), capability.detectedAt());
    }

    // ------------------------------------------------------------------- helpers

    private String now() {
        return Instant.now(clock).toString();
    }

    private String writeJson(Object value) {
        if (value == null) {
            return null;
        }
        try {
            return objectMapper.writeValueAsString(value);
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to serialize runtime payload", exception);
        }
    }

    private List<ToolCallRequest> readToolCalls(String json) {
        if (json == null || json.isBlank()) {
            return List.of();
        }
        try {
            List<ToolCallRequest> calls = objectMapper.readerFor(new TypeReference<List<ToolCallRequest>>() { })
                    .with(tools.jackson.databind.DeserializationFeature.FAIL_ON_TRAILING_TOKENS)
                    .readValue(json);
            if (calls == null || calls.stream().anyMatch(call -> call == null
                    || call.callId() == null || call.callId().isBlank()
                    || call.toolKey() == null || call.toolKey().isBlank()
                    || call.input() == null)) {
                throw new IllegalArgumentException("Stored tool calls require identifiers and object inputs");
            }
            var ids = new java.util.HashSet<String>();
            if (calls.stream().anyMatch(call -> !ids.add(call.callId()))) {
                throw new IllegalArgumentException("Stored tool calls require unique identifiers");
            }
            return List.copyOf(calls);
        } catch (Exception exception) {
            throw new IllegalStateException("Invalid persisted tool call data", exception);
        }
    }

    private static final RowMapper<AgentRunSession> SESSION_MAPPER = JdbcAgentRuntimeRepository::mapSession;
    private static final RowMapper<AgentRunEvent> EVENT_MAPPER = JdbcAgentRuntimeRepository::mapEvent;
    private static final RowMapper<AgentRunStep> STEP_MAPPER = JdbcAgentRuntimeRepository::mapStep;
    private static final RowMapper<AgentApproval> APPROVAL_MAPPER = JdbcAgentRuntimeRepository::mapApproval;
    private static final RowMapper<AgentToolInvocation> INVOCATION_MAPPER = JdbcAgentRuntimeRepository::mapInvocation;

    private static AgentRunSession mapSession(ResultSet rs, int rowNum) throws SQLException {
        return new AgentRunSession(
                rs.getString("id"),
                rs.getString("workspace_id"),
                rs.getString("task_id"),
                rs.getString("channel_id"),
                rs.getString("trigger_message_id"),
                rs.getString("initiator_user_id"),
                rs.getString("agent_key"),
                rs.getString("run_kind"),
                AgentRunStatus.fromStored(rs.getString("status")),
                rs.getString("goal"),
                rs.getString("context_summary"),
                rs.getString("error_message"),
                rs.getString("interruption_state"),
                rs.getString("resumed_from_session_id"),
                rs.getInt("step_count"),
                rs.getInt("approval_wait_count"),
                rs.getInt("attempt_count"),
                rs.getString("created_at"),
                rs.getString("started_at"),
                rs.getString("finished_at"),
                rs.getString("updated_at")
        );
    }

    private static AgentRunEvent mapEvent(ResultSet rs, int rowNum) throws SQLException {
        return new AgentRunEvent(
                rs.getString("id"),
                rs.getString("session_id"),
                rs.getString("workspace_id"),
                rs.getLong("seq"),
                rs.getString("event_type"),
                rs.getString("payload_json"),
                rs.getString("created_at")
        );
    }

    private static AgentRunStep mapStep(ResultSet rs, int rowNum) throws SQLException {
        return new AgentRunStep(
                rs.getString("id"),
                rs.getString("session_id"),
                rs.getInt("seq"),
                rs.getString("step_kind"),
                rs.getString("status"),
                rs.getString("agent_key"),
                rs.getString("title"),
                rs.getString("detail"),
                rs.getString("started_at"),
                rs.getString("finished_at")
        );
    }

    private static AgentApproval mapApproval(ResultSet rs, int rowNum) throws SQLException {
        return new AgentApproval(
                rs.getString("id"),
                rs.getString("session_id"),
                rs.getString("workspace_id"),
                rs.getString("step_id"),
                rs.getString("tool_key"),
                rs.getString("action"),
                rs.getString("target_resource"),
                rs.getString("risk_level"),
                rs.getString("impact_summary"),
                rs.getString("input_json"),
                AgentApprovalStatus.fromStored(rs.getString("status")),
                rs.getString("decided_by_user_id"),
                rs.getString("decision_note"),
                rs.getString("created_at"),
                rs.getString("decided_at")
        );
    }

    private static AgentToolInvocation mapInvocation(ResultSet rs, int rowNum) throws SQLException {
        return new AgentToolInvocation(
                rs.getString("id"),
                rs.getString("session_id"),
                rs.getString("workspace_id"),
                rs.getString("step_id"),
                rs.getString("tool_key"),
                rs.getString("idempotency_key"),
                AgentToolInvocation.Status.fromStored(rs.getString("status")),
                rs.getString("risk_level"),
                rs.getString("input_json"),
                rs.getString("output_json"),
                rs.getString("approval_id"),
                rs.getString("error_message"),
                rs.getInt("attempt_count"),
                rs.getString("created_at"),
                rs.getString("finished_at")
        );
    }
}
