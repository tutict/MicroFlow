package com.microflow.agent.runtime.domain.model;

import java.util.List;
import java.util.Map;

/**
 * A connector as seen outside the persistence layer.
 *
 * <p>Deliberately carries no secret material: {@code config} holds
 * non-sensitive settings (host, port, base URL) and {@code secretFields} only
 * names the secret keys that are stored, so a client can render "password: set"
 * without the value ever leaving the server.
 *
 * @param readEnabled  whether runs may read through this connector
 * @param writeEnabled whether runs may write through it, still behind approval
 */
public record AgentConnector(
        String id,
        String workspaceId,
        String ownerUserId,
        ConnectorKind kind,
        String name,
        Map<String, Object> config,
        List<String> secretFields,
        ConnectorSharingScope sharingScope,
        List<String> sharedUserIds,
        List<String> sharedAgentKeys,
        ConnectorStatus status,
        boolean readEnabled,
        boolean writeEnabled,
        String lastError,
        String lastCheckedAt,
        String createdAt,
        String updatedAt
) {

    /**
     * Whether this connector's credentials may be used at all by the given
     * person. Ownership always wins; sharing is explicit.
     */
    public boolean visibleTo(String userId) {
        if (userId == null || userId.isBlank()) {
            return false;
        }
        if (userId.equals(ownerUserId)) {
            return true;
        }
        return switch (sharingScope) {
            case PRIVATE -> false;
            case WORKSPACE -> true;
            case SELECTED -> sharedUserIds.contains(userId);
        };
    }

    /**
     * Whether the given agent may use it. An empty allow list means "any agent
     * in the workspace", which keeps the common case free of ceremony.
     */
    public boolean allowsAgent(String agentKey) {
        if (sharedAgentKeys.isEmpty()) {
            return true;
        }
        return agentKey != null && sharedAgentKeys.contains(agentKey);
    }

    public boolean usableBy(String userId, String agentKey) {
        return visibleTo(userId) && allowsAgent(agentKey);
    }

    public boolean readAllowedFor(String agentKey) {
        return readEnabled && kind.readCapable() && allowsAgent(agentKey);
    }

    public boolean writeAllowedFor(String agentKey) {
        return writeEnabled && kind.writeCapable() && allowsAgent(agentKey);
    }
}
