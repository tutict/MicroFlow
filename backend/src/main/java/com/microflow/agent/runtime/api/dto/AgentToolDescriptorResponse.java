package com.microflow.agent.runtime.api.dto;

import java.util.Map;

public record AgentToolDescriptorResponse(
        String key,
        String title,
        String description,
        Map<String, Object> inputSchema,
        String permission,
        String risk,
        boolean idempotent
) {
}
