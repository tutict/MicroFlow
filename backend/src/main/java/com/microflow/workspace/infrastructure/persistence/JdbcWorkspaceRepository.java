package com.microflow.workspace.infrastructure.persistence;

import com.microflow.agent.config.DiscoveredAgentBinding;
import com.microflow.workspace.domain.model.ChannelSummary;
import com.microflow.workspace.domain.model.ConversationKind;
import com.microflow.workspace.domain.model.ConversationSummary;
import com.microflow.workspace.domain.model.WorkspaceMemberSummary;
import com.microflow.workspace.domain.model.WorkspaceSummary;
import com.microflow.chat.infrastructure.encryption.CipherService;
import com.microflow.common.crypto.EncryptedPayload;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcWorkspaceRepository {

    private static final RowMapper<WorkspaceSummary> WORKSPACE_MAPPER = JdbcWorkspaceRepository::mapWorkspace;
    private static final RowMapper<ChannelSummary> CHANNEL_MAPPER = JdbcWorkspaceRepository::mapChannel;
    private static final RowMapper<WorkspaceMemberSummary> MEMBER_MAPPER = JdbcWorkspaceRepository::mapMember;

    private final JdbcTemplate jdbcTemplate;
    private final CipherService cipherService;
    private final Clock clock;

    public JdbcWorkspaceRepository(JdbcTemplate jdbcTemplate, CipherService cipherService, Clock clock) {
        this.jdbcTemplate = jdbcTemplate;
        this.cipherService = cipherService;
        this.clock = clock;
    }

    public String createDefaultWorkspace(
            String ownerUserId,
            String ownerDisplayName,
            List<DiscoveredAgentBinding> discoveredAgents
    ) {
        return createWorkspace(ownerUserId, ownerDisplayName + "'s Workspace", discoveredAgents);
    }

    public String createWorkspace(
            String ownerUserId,
            String workspaceName,
            List<DiscoveredAgentBinding> discoveredAgents
    ) {
        var workspaceId = "ws_" + UUID.randomUUID();
        var now = Instant.now(clock).toString();
        jdbcTemplate.update("""
                INSERT INTO workspaces(id, name, owner_user_id, created_at)
                VALUES (?, ?, ?, ?)
                """, workspaceId, workspaceName, ownerUserId, now);
        jdbcTemplate.update("""
                INSERT INTO workspace_members(workspace_id, user_id, role, joined_at)
                VALUES (?, ?, 'OWNER', ?)
                """, workspaceId, ownerUserId, now);
        createChannel(workspaceId, "general", now);
        createChannel(workspaceId, "build-and-release", now);
        createChannel(workspaceId, "knowledge", now);
        createChannel(workspaceId, "agent-runs", now);
        syncConfiguredAgents(workspaceId, discoveredAgents);
        return workspaceId;
    }

    public List<String> findAllWorkspaceIds() {
        return jdbcTemplate.query("""
                SELECT id
                FROM workspaces
                ORDER BY created_at ASC
                """, (rs, rowNum) -> rs.getString("id"));
    }

    public String findOwnedWorkspaceId(String ownerUserId) {
        return jdbcTemplate.query("""
                SELECT id
                FROM workspaces
                WHERE owner_user_id = ?
                ORDER BY created_at ASC
                LIMIT 1
                """, (rs, rowNum) -> rs.getString("id"), ownerUserId)
                .stream()
                .findFirst()
                .orElse(null);
    }

    public void addMemberIfAbsent(String workspaceId, String userId, String role) {
        jdbcTemplate.update("""
                INSERT OR IGNORE INTO workspace_members(workspace_id, user_id, role, joined_at)
                VALUES (?, ?, ?, ?)
                """, workspaceId, userId, role, Instant.now(clock).toString());
    }

    public List<WorkspaceSummary> findByUserId(String userId) {
        return jdbcTemplate.query("""
                SELECT w.id, w.name, COUNT(wm2.user_id) AS member_count
                FROM workspaces w
                JOIN workspace_members wm ON wm.workspace_id = w.id
                LEFT JOIN workspace_members wm2 ON wm2.workspace_id = w.id
                WHERE wm.user_id = ?
                GROUP BY w.id, w.name
                ORDER BY w.created_at ASC
                """, WORKSPACE_MAPPER, userId);
    }

    public java.util.Optional<WorkspaceSummary> findSummaryById(String workspaceId) {
        return jdbcTemplate.query("""
                SELECT w.id, w.name, COUNT(wm.user_id) AS member_count
                FROM workspaces w
                LEFT JOIN workspace_members wm ON wm.workspace_id = w.id
                WHERE w.id = ?
                GROUP BY w.id, w.name
                """, WORKSPACE_MAPPER, workspaceId).stream().findFirst();
    }

    public List<ChannelSummary> findChannels(String workspaceId, String userId) {
        return jdbcTemplate.query("""
                SELECT c.id, c.name, 0 AS unread_count
                FROM channels c
                JOIN workspace_members wm ON wm.workspace_id = c.workspace_id
                WHERE c.workspace_id = ? AND wm.user_id = ? AND c.type = 'ROOM'
                ORDER BY c.created_at ASC
                """, CHANNEL_MAPPER, workspaceId, userId);
    }

    public List<WorkspaceMemberSummary> findMembers(String workspaceId, String userId) {
        if (!isWorkspaceMember(workspaceId, userId)) {
            return List.of();
        }
        return jdbcTemplate.query("""
                SELECT u.id AS user_id, u.email, u.display_name, wm.role, wm.joined_at
                FROM workspace_members wm
                JOIN users u ON u.id = wm.user_id
                WHERE wm.workspace_id = ?
                ORDER BY CASE WHEN wm.role = 'OWNER' THEN 0 ELSE 1 END, u.display_name ASC
                """, MEMBER_MAPPER, workspaceId);
    }

    public List<ConversationSummary> findConversations(String workspaceId, String userId) {
        if (!isWorkspaceMember(workspaceId, userId)) {
            return List.of();
        }

        ensureDirectMessageChannels(workspaceId);
        ensureAgentConversationChannels(workspaceId);
        var conversations = new ArrayList<ConversationSummary>();
        conversations.addAll(enrichConversations(findChannelConversations(workspaceId, userId)));
        conversations.addAll(enrichConversations(findDirectMessageConversations(workspaceId, userId)));
        conversations.addAll(enrichConversations(findAgentConversations(workspaceId)));
        return conversations;
    }

    public boolean isWorkspaceMember(String workspaceId, String userId) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT COUNT(1)
                FROM workspace_members
                WHERE workspace_id = ? AND user_id = ?
                """, Integer.class, workspaceId, userId);
        return count != null && count > 0;
    }

    public boolean isWorkspaceOwner(String workspaceId, String userId) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT COUNT(1)
                FROM workspace_members
                WHERE workspace_id = ? AND user_id = ? AND role = 'OWNER'
                """, Integer.class, workspaceId, userId);
        return count != null && count > 0;
    }

    public boolean isChannelMember(String channelId, String userId) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT COUNT(1)
                FROM channels c
                WHERE c.id = ?
                  AND (
                    (
                      c.type IN ('ROOM', 'AGENT_DM')
                      AND EXISTS (
                        SELECT 1
                        FROM workspace_members wm
                        WHERE wm.workspace_id = c.workspace_id
                          AND wm.user_id = ?
                      )
                    )
                    OR (
                      c.type = 'DIRECT_MESSAGE'
                      AND (
                        c.name LIKE ('dm::' || ? || '::%')
                        OR c.name LIKE ('dm::%::' || ?)
                      )
                    )
                  )
                """, Integer.class, channelId, userId, userId, userId);
        return count != null && count > 0;
    }

    public String workspaceIdForChannel(String channelId) {
        return jdbcTemplate.queryForObject("""
                SELECT workspace_id
                FROM channels
                WHERE id = ?
                """, String.class, channelId);
    }

    public boolean isChannelInWorkspace(String workspaceId, String channelId) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT COUNT(1)
                FROM channels
                WHERE workspace_id = ? AND id = ?
                """, Integer.class, workspaceId, channelId);
        return count != null && count > 0;
    }

    public String findChannelIdByWorkspaceAndName(String workspaceId, String channelName) {
        return jdbcTemplate.query("""
                SELECT id
                FROM channels
                WHERE workspace_id = ? AND name = ?
                ORDER BY created_at ASC
                LIMIT 1
                """, (rs, rowNum) -> rs.getString("id"), workspaceId, channelName)
                .stream()
                .findFirst()
                .orElse(null);
    }

    public void syncConfiguredAgents(String workspaceId, List<DiscoveredAgentBinding> discoveredAgents) {
        if (discoveredAgents == null || discoveredAgents.isEmpty()) {
            return;
        }
        var now = Instant.now(clock).toString();
        for (var binding : discoveredAgents) {
            upsertAgent(workspaceId, binding, now);
            ensureAgentThreadChannel(workspaceId, binding.agentKey(), now);
        }
    }

    private void createChannel(String workspaceId, String channelName, String now) {
        jdbcTemplate.update("""
                INSERT INTO channels(id, workspace_id, name, type, created_at)
                VALUES (?, ?, ?, 'ROOM', ?)
                """, "chn_" + UUID.randomUUID(), workspaceId, channelName, now);
    }

    private void upsertAgent(String workspaceId, DiscoveredAgentBinding binding, String now) {
        var encryptedCredential = cipherService.encrypt(binding.credential() == null ? "" : binding.credential());
        jdbcTemplate.update("""
                INSERT INTO agent_configs(
                    id, workspace_id, agent_key, provider, endpoint_url,
                    credential_ciphertext, credential_iv, credential_key_version,
                    enabled, created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
                ON CONFLICT(workspace_id, agent_key)
                DO UPDATE SET
                    provider = excluded.provider,
                    endpoint_url = excluded.endpoint_url,
                    credential_ciphertext = excluded.credential_ciphertext,
                    credential_iv = excluded.credential_iv,
                    credential_key_version = excluded.credential_key_version,
                    enabled = 1,
                    updated_at = excluded.updated_at
                """,
                "agt_" + UUID.randomUUID(),
                workspaceId,
                binding.agentKey(),
                binding.provider(),
                binding.endpointUrl(),
                encryptedCredential.ciphertext(),
                encryptedCredential.iv(),
                encryptedCredential.keyVersion(),
                now,
                now
        );
    }

    private void ensureAgentThreadChannel(String workspaceId, String agentKey, String now) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT COUNT(1)
                FROM channels
                WHERE workspace_id = ?
                  AND type = 'AGENT_DM'
                  AND name = ?
                """, Integer.class, workspaceId, "agent::" + agentKey);
        if (count == null || count == 0) {
            createAgentThreadChannel(workspaceId, agentKey, now);
        }
    }

    private List<ConversationSummary> findChannelConversations(String workspaceId, String userId) {
        return jdbcTemplate.query("""
                SELECT c.id, c.name, 0 AS unread_count
                FROM channels c
                JOIN workspace_members wm ON wm.workspace_id = c.workspace_id
                WHERE c.workspace_id = ? AND wm.user_id = ? AND c.type = 'ROOM'
                ORDER BY c.created_at ASC
                """, (rs, rowNum) -> new ConversationSummary(
                rs.getString("id"),
                rs.getString("name"),
                "#" + rs.getString("name"),
                ConversationKind.CHANNEL,
                rs.getInt("unread_count"),
                true,
                null
        ), workspaceId, userId);
    }

    private List<ConversationSummary> findDirectMessageConversations(String workspaceId, String userId) {
        return jdbcTemplate.query("""
                SELECT c.id, u.id AS peer_user_id, u.display_name
                FROM workspace_members wm
                JOIN users u ON u.id = wm.user_id
                JOIN channels c
                  ON c.workspace_id = wm.workspace_id
                 AND c.type = 'DIRECT_MESSAGE'
                 AND c.name = CASE
                        WHEN ? < u.id THEN ('dm::' || ? || '::' || u.id)
                        ELSE ('dm::' || u.id || '::' || ?)
                     END
                WHERE wm.workspace_id = ? AND wm.user_id <> ?
                ORDER BY u.display_name ASC
                """, (rs, rowNum) -> new ConversationSummary(
                rs.getString("id"),
                rs.getString("display_name"),
                "1:1 team conversation",
                ConversationKind.DIRECT_MESSAGE,
                0,
                true,
                null
        ), userId, userId, userId, workspaceId, userId);
    }

    private List<ConversationSummary> findAgentConversations(String workspaceId) {
        return jdbcTemplate.query("""
                SELECT c.id, ac.agent_key, ac.enabled
                FROM agent_configs ac
                JOIN channels c
                  ON c.workspace_id = ac.workspace_id
                 AND c.type = 'AGENT_DM'
                 AND c.name = ('agent::' || ac.agent_key)
                WHERE ac.workspace_id = ?
                ORDER BY agent_key ASC
                """, (rs, rowNum) -> new ConversationSummary(
                rs.getString("id"),
                "@" + rs.getString("agent_key"),
                "Private thread with AI coworker",
                ConversationKind.AGENT_DM,
                0,
                rs.getInt("enabled") == 1,
                null
        ), workspaceId);
    }

    private List<ConversationSummary> enrichConversations(List<ConversationSummary> conversations) {
        return conversations.stream()
                .map(this::enrichConversation)
                .toList();
    }

    private ConversationSummary enrichConversation(ConversationSummary conversation) {
        var latestMessage = findLatestMessage(conversation.id());
        if (latestMessage == null) {
            return conversation;
        }
        return new ConversationSummary(
                conversation.id(),
                conversation.title(),
                summarizeMessage(latestMessage.content()),
                conversation.kind(),
                conversation.unreadCount(),
                conversation.available(),
                latestMessage.createdAt()
        );
    }

    private void ensureAgentConversationChannels(String workspaceId) {
        var missingAgentKeys = jdbcTemplate.query("""
                SELECT ac.agent_key
                FROM agent_configs ac
                LEFT JOIN channels c
                  ON c.workspace_id = ac.workspace_id
                 AND c.type = 'AGENT_DM'
                 AND c.name = ('agent::' || ac.agent_key)
                WHERE ac.workspace_id = ? AND c.id IS NULL
                ORDER BY ac.agent_key ASC
                """, (rs, rowNum) -> rs.getString("agent_key"), workspaceId);
        if (missingAgentKeys.isEmpty()) {
            return;
        }
        var now = Instant.now(clock).toString();
        for (var agentKey : missingAgentKeys) {
            createAgentThreadChannel(workspaceId, agentKey, now);
        }
    }

    private void ensureDirectMessageChannels(String workspaceId) {
        var memberIds = jdbcTemplate.query("""
                SELECT user_id
                FROM workspace_members
                WHERE workspace_id = ?
                ORDER BY user_id ASC
                """, (rs, rowNum) -> rs.getString("user_id"), workspaceId);
        if (memberIds.size() < 2) {
            return;
        }
        var now = Instant.now(clock).toString();
        for (var leftIndex = 0; leftIndex < memberIds.size(); leftIndex++) {
            for (var rightIndex = leftIndex + 1; rightIndex < memberIds.size(); rightIndex++) {
                createDirectMessageChannel(workspaceId, memberIds.get(leftIndex), memberIds.get(rightIndex), now);
            }
        }
    }

    private void createAgentThreadChannel(String workspaceId, String agentKey, String now) {
        jdbcTemplate.update("""
                INSERT INTO channels(id, workspace_id, name, type, created_at)
                VALUES (?, ?, ?, 'AGENT_DM', ?)
                """, "chn_" + UUID.randomUUID(), workspaceId, "agent::" + agentKey, now);
    }

    private void createDirectMessageChannel(String workspaceId, String leftUserId, String rightUserId, String now) {
        jdbcTemplate.update("""
                INSERT INTO channels(id, workspace_id, name, type, created_at)
                SELECT ?, ?, ?, 'DIRECT_MESSAGE', ?
                WHERE NOT EXISTS (
                    SELECT 1
                    FROM channels
                    WHERE workspace_id = ?
                      AND name = ?
                      AND type = 'DIRECT_MESSAGE'
                )
                """,
                "chn_" + UUID.randomUUID(),
                workspaceId,
                directMessageChannelName(leftUserId, rightUserId),
                now,
                workspaceId,
                directMessageChannelName(leftUserId, rightUserId));
    }

    private String directMessageChannelName(String leftUserId, String rightUserId) {
        if (leftUserId.compareTo(rightUserId) <= 0) {
            return "dm::" + leftUserId + "::" + rightUserId;
        }
        return "dm::" + rightUserId + "::" + leftUserId;
    }

    private ConversationMessagePreview findLatestMessage(String channelId) {
        return jdbcTemplate.query("""
                SELECT ciphertext, iv, key_version, created_at
                FROM messages
                WHERE channel_id = ?
                ORDER BY created_at DESC
                LIMIT 1
                """, (rs, rowNum) -> new ConversationMessagePreview(
                cipherService.decrypt(new EncryptedPayload(
                        rs.getBytes("ciphertext"),
                        rs.getBytes("iv"),
                        rs.getInt("key_version")
                )),
                rs.getString("created_at")
        ), channelId).stream().findFirst().orElse(null);
    }

    private String summarizeMessage(String content) {
        var normalized = content == null ? "" : content.trim().replaceAll("\\s+", " ");
        if (normalized.isBlank()) {
            return "";
        }
        if (normalized.length() <= 72) {
            return normalized;
        }
        return normalized.substring(0, 72) + "...";
    }

    private record ConversationMessagePreview(String content, String createdAt) {
    }

    private static WorkspaceSummary mapWorkspace(ResultSet rs, int rowNum) throws SQLException {
        return new WorkspaceSummary(
                rs.getString("id"),
                rs.getString("name"),
                rs.getInt("member_count")
        );
    }

    private static ChannelSummary mapChannel(ResultSet rs, int rowNum) throws SQLException {
        return new ChannelSummary(
                rs.getString("id"),
                rs.getString("name"),
                rs.getInt("unread_count")
        );
    }

    private static WorkspaceMemberSummary mapMember(ResultSet rs, int rowNum) throws SQLException {
        return new WorkspaceMemberSummary(
                rs.getString("user_id"),
                rs.getString("email"),
                rs.getString("display_name"),
                rs.getString("role"),
                rs.getString("joined_at")
        );
    }
}
