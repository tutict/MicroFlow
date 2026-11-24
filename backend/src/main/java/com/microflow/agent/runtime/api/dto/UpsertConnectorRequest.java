package com.microflow.agent.runtime.api.dto;

import java.util.List;
import java.util.Map;

/**
 * Create/update payload for a connector.
 *
 * <p>{@code secrets} is write-only: the controller passes it straight to the
 * service and it is encrypted at rest. Omitting it on an update keeps the stored
 * credential, which is what the settings screen sends when the user only renames
 * or reshapes sharing.
 */
public record UpsertConnectorRequest(
        String kind,
        String name,
        Map<String, Object> config,
        Map<String, String> secrets,
        String sharingScope,
        List<String> sharedUserIds,
        List<String> sharedAgentKeys,
        Boolean readEnabled,
        Boolean writeEnabled
) {
}
