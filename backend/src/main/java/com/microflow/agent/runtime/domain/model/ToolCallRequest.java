package com.microflow.agent.runtime.domain.model;

import java.util.Map;

/**
 * One tool invocation requested by the model.
 *
 * <p>{@code callId} is assigned by the provider (or by the legacy adapter before
 * persistence) and doubles as the idempotency key: replaying the same provider
 * turn can never execute the same write twice.
 */
public record ToolCallRequest(
        String callId,
        String toolKey,
        Map<String, Object> input
) {

    public Map<String, Object> inputOrEmpty() {
        return input == null ? Map.of() : input;
    }
}
