package com.microflow.agent.runtime.domain.model;

import java.util.Map;

/**
 * Declaration of a tool the runtime is willing to execute.
 *
 * @param key             stable identifier the model calls, for example {@code task.update_status}
 * @param title           short human label used in approval cards
 * @param description     what the tool does, shown to the model
 * @param inputSchema     JSON-schema-like shape, validated by the handler
 * @param permission      AUTO runs inline, APPROVAL pauses the run first
 * @param risk            blast radius, drives approval wording
 * @param idempotent      whether repeating the same call is safe
 * @param connectorKind   connector a tool needs, or {@code null} for built-ins
 */
public record ToolDescriptor(
        String key,
        String title,
        String description,
        Map<String, Object> inputSchema,
        ToolPolicy.Permission permission,
        ToolPolicy.Risk risk,
        boolean idempotent,
        String connectorKind
) {

    public boolean requiresApproval() {
        return permission == ToolPolicy.Permission.APPROVAL;
    }
}
