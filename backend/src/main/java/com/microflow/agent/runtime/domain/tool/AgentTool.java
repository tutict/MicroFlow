package com.microflow.agent.runtime.domain.tool;

import com.microflow.agent.runtime.domain.model.ToolDescriptor;
import java.util.Map;

/** A registered capability the runtime may execute. */
public interface AgentTool {

    ToolDescriptor descriptor();

    /** Checks resource-specific authority without performing the action. */
    default void authorize(ToolContext context, String actorUserId, Map<String, Object> input) {
    }

    ToolResult invoke(ToolContext context, Map<String, Object> input);
}
