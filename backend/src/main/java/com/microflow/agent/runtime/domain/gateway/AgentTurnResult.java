package com.microflow.agent.runtime.domain.gateway;

import com.microflow.agent.runtime.domain.model.ToolCallRequest;
import java.util.List;

/**
 * Result of one provider turn.
 *
 * <p>Only {@link Kind#TOOL_CALLS} may trigger a tool. The runtime never infers an
 * action from prose, so a provider that cannot emit structured calls simply
 * produces text and the run ends without side effects.
 */
public record AgentTurnResult(
        Kind kind,
        String text,
        List<ToolCallRequest> toolCalls,
        String error
) {

    public enum Kind {
        TEXT,
        TOOL_CALLS,
        FAILED
    }

    public static AgentTurnResult text(String text) {
        return new AgentTurnResult(Kind.TEXT, text, List.of(), null);
    }

    public static AgentTurnResult toolCalls(List<ToolCallRequest> calls, String text) {
        return new AgentTurnResult(Kind.TOOL_CALLS, text, List.copyOf(calls), null);
    }

    public static AgentTurnResult failed(String error) {
        return new AgentTurnResult(Kind.FAILED, null, List.of(), error);
    }
}
