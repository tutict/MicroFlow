package com.microflow.agent.runtime.domain.gateway;

import java.util.List;

/**
 * One message of the provider-side conversation.
 *
 * <p>Assistant messages may carry tool calls; tool messages answer exactly one
 * of them via {@code toolCallId}. The runtime persists these rows so a run can
 * resume after an approval in a different process.
 */
public record TurnMessage(
        String role,
        String content,
        List<com.microflow.agent.runtime.domain.model.ToolCallRequest> toolCalls,
        String toolCallId
) {

    public static TurnMessage user(String content) {
        return new TurnMessage("user", content, List.of(), null);
    }

    public static TurnMessage assistant(String content) {
        return new TurnMessage("assistant", content, List.of(), null);
    }

    public static TurnMessage tool(String toolCallId, String content) {
        return new TurnMessage("tool", content, List.of(), toolCallId);
    }
}
