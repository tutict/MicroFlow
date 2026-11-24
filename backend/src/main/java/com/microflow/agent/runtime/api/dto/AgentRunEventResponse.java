package com.microflow.agent.runtime.api.dto;

import java.util.Map;

public record AgentRunEventResponse(
        String id,
        long seq,
        String type,
        Map<String, Object> payload,
        String createdAt
) {
}
