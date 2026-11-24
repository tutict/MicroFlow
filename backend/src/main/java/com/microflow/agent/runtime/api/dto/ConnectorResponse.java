package com.microflow.agent.runtime.api.dto;

import java.util.List;
import java.util.Map;

/**
 * A connector as returned by the API. Credentials are represented by
 * {@code secretFields} (names only) and never by value.
 */
public record ConnectorResponse(
        String id,
        String workspaceId,
        String ownerUserId,
        boolean ownedByMe,
        String kind,
        String name,
        Map<String, Object> config,
        List<String> secretFields,
        String sharingScope,
        List<String> sharedUserIds,
        List<String> sharedAgentKeys,
        String status,
        boolean readEnabled,
        boolean writeEnabled,
        String lastError,
        String lastCheckedAt,
        String createdAt,
        String updatedAt
) {
}
