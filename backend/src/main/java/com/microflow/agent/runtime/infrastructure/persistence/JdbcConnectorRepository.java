package com.microflow.agent.runtime.infrastructure.persistence;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.microflow.agent.runtime.domain.model.AgentConnector;
import com.microflow.agent.runtime.domain.model.ConnectorKind;
import com.microflow.agent.runtime.domain.model.ConnectorSharingScope;
import com.microflow.agent.runtime.domain.model.ConnectorStatus;
import com.microflow.chat.infrastructure.encryption.CipherService;
import com.microflow.common.crypto.EncryptedPayload;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import com.microflow.common.jdbc.JdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Persistence for connectors and their encrypted credentials.
 *
 * <p>The secret blob leaves this class as plaintext only through
 * {@link #findCredentials(String)}, which is called by the executor right before
 * a real external call and by the connectivity probe. Every read path aimed at
 * the API returns the secret <em>field names</em> only, so the settings screen
 * can render "password: set" without the value crossing the wire twice.
 */
@Repository
public class JdbcConnectorRepository {

    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {
    };
    private static final TypeReference<Map<String, String>> SECRET_TYPE = new TypeReference<>() {
    };
    private static final TypeReference<List<String>> LIST_TYPE = new TypeReference<>() {
    };

    private static final String COLUMNS = """
            id, workspace_id, owner_user_id, connector_kind, name, config_json,
            secret_ciphertext, secret_iv, secret_key_version, sharing_scope,
            shared_user_ids, shared_agent_keys, status, last_error, last_checked_at,
            read_enabled, write_enabled, created_at, updated_at
            """;

    private final JdbcTemplate jdbcTemplate;
    private final CipherService cipherService;
    private final ObjectMapper objectMapper;
    private final Clock clock;

    public JdbcConnectorRepository(
            JdbcTemplate jdbcTemplate,
            CipherService cipherService,
            ObjectMapper objectMapper,
            Clock clock
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.cipherService = cipherService;
        this.objectMapper = objectMapper;
        this.clock = clock;
    }

    public AgentConnector insert(
            String workspaceId,
            String ownerUserId,
            ConnectorKind kind,
            String name,
            Map<String, Object> config,
            Map<String, String> secrets,
            ConnectorSharingScope sharingScope,
            List<String> sharedUserIds,
            List<String> sharedAgentKeys,
            boolean readEnabled,
            boolean writeEnabled
    ) {
        var id = "con_" + UUID.randomUUID();
        var now = Instant.now(clock).toString();
        var encrypted = cipherService.encrypt(writeSecrets(secrets));
        jdbcTemplate.update("""
                INSERT INTO agent_connectors(
                    id, workspace_id, owner_user_id, connector_kind, name, config_json,
                    secret_ciphertext, secret_iv, secret_key_version, sharing_scope,
                    shared_user_ids, shared_agent_keys, status, last_error, last_checked_at,
                    read_enabled, write_enabled, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, ?, ?, ?, ?)
                """,
                id,
                workspaceId,
                ownerUserId,
                kind.name(),
                name,
                writeJson(config),
                encrypted.ciphertext(),
                encrypted.iv(),
                encrypted.keyVersion(),
                sharingScope.name(),
                writeJson(sharedUserIds),
                writeJson(sharedAgentKeys),
                ConnectorStatus.UNVERIFIED.name(),
                readEnabled ? 1 : 0,
                writeEnabled ? 1 : 0,
                now,
                now
        );
        return find(id).orElseThrow();
    }

    /**
     * Updates the mutable parts of a connector.
     *
     * @param secrets null preserves all credentials; a non-empty map patches
     *                only its fields; an explicitly empty map clears credentials
     */
    public synchronized AgentConnector update(
            String id,
            String name,
            Map<String, Object> config,
            Map<String, String> secrets,
            ConnectorSharingScope sharingScope,
            List<String> sharedUserIds,
            List<String> sharedAgentKeys,
            boolean readEnabled,
            boolean writeEnabled
    ) {
        var now = Instant.now(clock).toString();
        if (secrets == null) {
            jdbcTemplate.update("""
                    UPDATE agent_connectors
                    SET name = ?, config_json = ?, sharing_scope = ?, shared_user_ids = ?,
                        shared_agent_keys = ?, read_enabled = ?, write_enabled = ?,
                        status = ?, last_error = NULL, updated_at = ?
                    WHERE id = ?
                    """,
                    name,
                    writeJson(config),
                    sharingScope.name(),
                    writeJson(sharedUserIds),
                    writeJson(sharedAgentKeys),
                    readEnabled ? 1 : 0,
                    writeEnabled ? 1 : 0,
                    ConnectorStatus.UNVERIFIED.name(),
                    now,
                    id
            );
        } else {
            var patched = secrets.isEmpty() ? Map.<String, String>of()
                    : new java.util.LinkedHashMap<>(findCredentials(id));
            if (!secrets.isEmpty()) patched.putAll(secrets);
            var encrypted = cipherService.encrypt(writeSecrets(patched));
            jdbcTemplate.update("""
                    UPDATE agent_connectors
                    SET name = ?, config_json = ?, secret_ciphertext = ?, secret_iv = ?,
                        secret_key_version = ?, sharing_scope = ?, shared_user_ids = ?,
                        shared_agent_keys = ?, read_enabled = ?, write_enabled = ?,
                        status = ?, last_error = NULL, last_checked_at = NULL, updated_at = ?
                    WHERE id = ?
                    """,
                    name,
                    writeJson(config),
                    encrypted.ciphertext(),
                    encrypted.iv(),
                    encrypted.keyVersion(),
                    sharingScope.name(),
                    writeJson(sharedUserIds),
                    writeJson(sharedAgentKeys),
                    readEnabled ? 1 : 0,
                    writeEnabled ? 1 : 0,
                    ConnectorStatus.UNVERIFIED.name(),
                    now,
                    id
            );
        }
        return find(id).orElseThrow();
    }

    public Optional<AgentConnector> find(String id) {
        return jdbcTemplate.query(
                "SELECT " + COLUMNS + " FROM agent_connectors WHERE id = ?",
                this::map,
                id
        ).stream().findFirst();
    }

    /** All connectors in a workspace, owner-agnostic; callers filter by visibility. */
    public List<AgentConnector> listByWorkspace(String workspaceId) {
        return jdbcTemplate.query(
                "SELECT " + COLUMNS + " FROM agent_connectors"
                        + " WHERE workspace_id = ? ORDER BY created_at DESC",
                this::map,
                workspaceId
        );
    }

    /**
     * Plaintext credentials for one connector.
     *
     * <p>Only the executor and the connectivity probe may call this. The result
     * must never be serialised into an API response, an event payload or a log
     * line.
     */
    public Map<String, String> findCredentials(String id) {
        var payloads = jdbcTemplate.query("""
                SELECT secret_ciphertext, secret_iv, secret_key_version
                FROM agent_connectors WHERE id = ?
                """, (rs, rowNum) -> new EncryptedPayload(
                rs.getBytes("secret_ciphertext"),
                rs.getBytes("secret_iv"),
                rs.getInt("secret_key_version")
        ), id);
        if (payloads.isEmpty()) {
            return Map.of();
        }
        return decryptSecrets(payloads.get(0));
    }

    public void markChecked(String id, ConnectorStatus status, String error) {
        var now = Instant.now(clock).toString();
        jdbcTemplate.update("""
                UPDATE agent_connectors
                SET status = ?, last_error = ?, last_checked_at = ?, updated_at = ?
                WHERE id = ?
                """,
                status.name(),
                truncate(error, 300),
                now,
                now,
                id
        );
    }

    public boolean delete(String id) {
        return jdbcTemplate.update("DELETE FROM agent_connectors WHERE id = ?", id) > 0;
    }

    // ------------------------------------------------------------------ mapping

    private AgentConnector map(ResultSet rs, int rowNum) throws SQLException {
        var kind = ConnectorKind.parse(rs.getString("connector_kind"));
        return new AgentConnector(
                rs.getString("id"),
                rs.getString("workspace_id"),
                rs.getString("owner_user_id"),
                kind,
                rs.getString("name"),
                readMap(rs.getString("config_json")),
                secretFieldNames(rs),
                ConnectorSharingScope.parse(rs.getString("sharing_scope")),
                readList(rs.getString("shared_user_ids")),
                readList(rs.getString("shared_agent_keys")),
                parseStatus(rs.getString("status")),
                rs.getInt("read_enabled") == 1,
                rs.getInt("write_enabled") == 1,
                rs.getString("last_error"),
                rs.getString("last_checked_at"),
                rs.getString("created_at"),
                rs.getString("updated_at")
        );
    }

    private static ConnectorStatus parseStatus(String value) {
        try {
            return ConnectorStatus.valueOf(value);
        } catch (IllegalArgumentException | NullPointerException exception) {
            return ConnectorStatus.UNVERIFIED;
        }
    }

    /**
     * Secret key names without their values.
     *
     * <p>Decrypting here is intentional: the settings screen has to say
     * "password is set" while the value stays server-side. The payload is a few
     * dozen bytes and the plaintext never escapes this method.
     */
    private List<String> secretFieldNames(ResultSet rs) throws SQLException {
        var payload = new EncryptedPayload(
                rs.getBytes("secret_ciphertext"),
                rs.getBytes("secret_iv"),
                rs.getInt("secret_key_version")
        );
        if (payload.ciphertext() == null || payload.ciphertext().length == 0) {
            return List.of();
        }
        return decryptSecrets(payload).keySet().stream().sorted().toList();
    }

    private Map<String, String> decryptSecrets(EncryptedPayload payload) {
        var json = cipherService.decrypt(payload);
        if (json == null || json.isBlank()) {
            return Map.of();
        }
        try {
            return Map.copyOf(objectMapper.readValue(json, SECRET_TYPE));
        } catch (Exception exception) {
            throw new IllegalStateException("Stored connector credentials are unreadable", exception);
        }
    }

    private Map<String, Object> readMap(String json) {
        if (json == null || json.isBlank()) {
            return Map.of();
        }
        try {
            return objectMapper.readValue(json, MAP_TYPE);
        } catch (Exception exception) {
            return Map.of();
        }
    }

    private List<String> readList(String json) {
        if (json == null || json.isBlank()) {
            return List.of();
        }
        try {
            return objectMapper.readValue(json, LIST_TYPE);
        } catch (Exception exception) {
            return List.of();
        }
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value == null ? Map.of() : value);
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to serialize connector payload", exception);
        }
    }

    private String writeSecrets(Map<String, String> secrets) {
        try {
            return objectMapper.writeValueAsString(secrets == null ? Map.of() : secrets);
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to serialize connector credentials", exception);
        }
    }

    private static String truncate(String value, int max) {
        if (value == null) {
            return null;
        }
        return value.length() <= max ? value : value.substring(0, max);
    }
}
