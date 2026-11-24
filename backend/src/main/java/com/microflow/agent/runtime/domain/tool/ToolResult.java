package com.microflow.agent.runtime.domain.tool;

import java.util.Map;

/** Result of a tool execution, already reduced to something a model can read. */
public record ToolResult(
        boolean success,
        Map<String, Object> output,
        String summary,
        String error,
        boolean uncertain
) {

    public static ToolResult ok(Map<String, Object> output, String summary) {
        return new ToolResult(true, output == null ? Map.of() : output, summary, null, false);
    }

    public static ToolResult failed(String error) {
        return new ToolResult(false, Map.of(), null, error, false);
    }

    /**
     * The side effect may or may not have landed. Callers must not retry this
     * automatically; a human has to confirm the external state first.
     */
    public static ToolResult unknown(String error) {
        return new ToolResult(false, Map.of(), null, error, true);
    }
}
