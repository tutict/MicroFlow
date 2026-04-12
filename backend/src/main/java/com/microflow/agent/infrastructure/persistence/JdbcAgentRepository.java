package com.microflow.agent.infrastructure.persistence;

import com.microflow.agent.domain.model.AgentExecutionTarget;
import com.microflow.chat.infrastructure.encryption.CipherService;
import com.microflow.common.crypto.EncryptedPayload;
import com.microflow.agent.domain.model.AgentDescriptor;
import com.microflow.agent.domain.model.AgentRunLog;
import com.microflow.agent.domain.model.ConfiguredAgent;
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
public class JdbcAgentRepository {

    private static final RowMapper<AgentDescriptor> AGENT_MAPPER = JdbcAgentRepository::mapAgent;
    private static final RowMapper<AgentRunLog> RUN_MAPPER = JdbcAgentRepository::mapRun;

    private final JdbcTemplate jdbcTemplate;
    private final Clock clock;
    private final CipherService cipherService;

    public JdbcAgentRepository(JdbcTemplate jdbcTemplate, Clock clock, CipherService cipherService) {
        this.jdbcTemplate = jdbcTemplate;
        this.clock = clock;
        this.cipherService = cipherService;
    }

    public List<AgentDescriptor> listAgents(String workspaceId) {
        return jdbcTemplate.query("""
                SELECT agent_key, provider, enabled
                FROM agent_configs
                WHERE workspace_id = ?
                ORDER BY agent_key ASC
                """, AGENT_MAPPER, workspaceId);
    }

    public String findRoleStrategy(String workspaceId, String agentKey) {
        var results = jdbcTemplate.queryForList("""
                SELECT role_strategy
                FROM agent_configs
                WHERE workspace_id = ? AND agent_key = ?
                LIMIT 1
                """, String.class, workspaceId, agentKey);
        return results.isEmpty() ? null : results.getFirst();
    }

    public void updateRoleStrategy(String workspaceId, String agentKey, String roleStrategy) {
        var updated = jdbcTemplate.update("""
                UPDATE agent_configs
                SET role_strategy = ?, updated_at = ?
                WHERE workspace_id = ? AND agent_key = ?
                """, normalizeRoleStrategy(roleStrategy), Instant.now(clock).toString(), workspaceId, agentKey);
        if (updated == 0) {
            throw new IllegalArgumentException("Agent is not configured");
        }
    }

    public boolean existsAgent(String workspaceId, String agentKey) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT COUNT(1)
                FROM agent_configs
                WHERE workspace_id = ? AND agent_key = ? AND enabled = 1
                """, Integer.class, workspaceId, agentKey);
        return count != null && count > 0;
    }

    public String findBoundAgentKeyForChannel(String channelId) {
        return jdbcTemplate.query("""
                SELECT ac.agent_key
                FROM channels c
                JOIN agent_configs ac
                  ON ac.workspace_id = c.workspace_id
                 AND c.type = 'AGENT_DM'
                 AND c.name = ('agent::' || ac.agent_key)
                WHERE c.id = ? AND ac.enabled = 1
                LIMIT 1
                """, (rs, rowNum) -> rs.getString("agent_key"), channelId)
                .stream()
                .findFirst()
                .orElse(null);
    }

    public String createRun(String workspaceId, String channelId, String triggerMessageId, String agentKey) {
        var runId = "run_" + UUID.randomUUID();
        var provider = jdbcTemplate.query("""
                SELECT provider
                FROM agent_configs
                WHERE workspace_id = ? AND agent_key = ?
                LIMIT 1
                """, (rs, rowNum) -> rs.getString("provider"), workspaceId, agentKey)
                .stream()
                .findFirst()
                .orElse("mock-openclaw");
        jdbcTemplate.update("""
                INSERT INTO agent_runs(
                    id, workspace_id, channel_id, trigger_message_id, agent_key,
                    provider, status, error_message, attempt_count, result_message_id,
                    created_at, started_at, finished_at
                )
                VALUES (?, ?, ?, ?, ?, ?, 'QUEUED', NULL, 0, NULL, ?, NULL, NULL)
                """, runId, workspaceId, channelId, triggerMessageId, agentKey, provider, Instant.now(clock).toString());
        return runId;
    }

    public void markStarted(String runId) {
        jdbcTemplate.update("""
                UPDATE agent_runs
                SET status = 'RUNNING', started_at = ?, attempt_count = attempt_count + 1
                WHERE id = ?
                """, Instant.now(clock).toString(), runId);
    }

    public void markCompleted(String runId, String resultMessageId) {
        jdbcTemplate.update("""
                UPDATE agent_runs
                SET status = 'COMPLETED', result_message_id = ?, finished_at = ?, error_message = NULL
                WHERE id = ?
                """, resultMessageId, Instant.now(clock).toString(), runId);
    }

    public void markFailed(String runId, String errorMessage) {
        jdbcTemplate.update("""
                UPDATE agent_runs
                SET status = 'FAILED', error_message = ?, finished_at = ?
                WHERE id = ?
                """, errorMessage, Instant.now(clock).toString(), runId);
    }

    public AgentExecutionTarget findExecutionTarget(String workspaceId, String agentKey) {
        return jdbcTemplate.query("""
                SELECT provider, endpoint_url, credential_ciphertext, credential_iv, credential_key_version
                FROM agent_configs
                WHERE workspace_id = ? AND agent_key = ? AND enabled = 1
                LIMIT 1
                """, (rs, rowNum) -> new AgentExecutionTarget(
                rs.getString("provider"),
                rs.getString("endpoint_url"),
                cipherService.decrypt(new EncryptedPayload(
                        rs.getBytes("credential_ciphertext"),
                        rs.getBytes("credential_iv"),
                        rs.getInt("credential_key_version")
                ))
        ), workspaceId, agentKey).stream().findFirst().orElse(null);
    }

    public List<AgentRunLog> listRuns(String workspaceId) {
        return jdbcTemplate.query("""
                SELECT id, agent_key, status, trigger_message_id, result_message_id, created_at, finished_at, error_message
                FROM agent_runs
                WHERE workspace_id = ?
                ORDER BY created_at DESC
                LIMIT 50
                """, RUN_MAPPER, workspaceId);
    }

    public List<ConfiguredAgent> listConfiguredAgents(String workspaceId) {
        return jdbcTemplate.query("""
                SELECT agent_key, provider, endpoint_url, credential_ciphertext, credential_iv, credential_key_version, enabled, role_strategy
                FROM agent_configs
                WHERE workspace_id = ?
                ORDER BY agent_key ASC
                """, (rs, rowNum) -> new ConfiguredAgent(
                rs.getString("agent_key"),
                rs.getString("provider"),
                rs.getString("endpoint_url"),
                cipherService.decrypt(new EncryptedPayload(
                        rs.getBytes("credential_ciphertext"),
                        rs.getBytes("credential_iv"),
                        rs.getInt("credential_key_version")
                )),
                rs.getInt("enabled") == 1,
                rs.getString("role_strategy")
        ), workspaceId);
    }

    private String normalizeRoleStrategy(String roleStrategy) {
        if (roleStrategy == null) {
            return null;
        }
        var normalized = roleStrategy.trim();
        return normalized.isEmpty() ? null : normalized;
    }

    private static AgentDescriptor mapAgent(ResultSet rs, int rowNum) throws SQLException {
        return new AgentDescriptor(
                rs.getString("agent_key"),
                rs.getString("provider"),
                rs.getInt("enabled") == 1
        );
    }

    private static AgentRunLog mapRun(ResultSet rs, int rowNum) throws SQLException {
        return new AgentRunLog(
                rs.getString("id"),
                rs.getString("agent_key"),
                rs.getString("status"),
                rs.getString("trigger_message_id"),
                rs.getString("result_message_id"),
                rs.getString("created_at"),
                rs.getString("finished_at"),
                rs.getString("error_message")
        );
    }
}
