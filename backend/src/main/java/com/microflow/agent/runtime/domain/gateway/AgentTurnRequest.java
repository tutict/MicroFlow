package com.microflow.agent.runtime.domain.gateway;

import com.microflow.agent.runtime.domain.model.ToolDescriptor;
import java.util.List;

/** A structured turn request: prompt, prior messages and the tools on offer. */
public record AgentTurnRequest(
        String sessionId,
        String workspaceId,
        String channelId,
        String agentKey,
        String goal,
        String contextBlock,
        List<TurnMessage> messages,
        List<ToolDescriptor> tools,
        boolean toolsEnabled
) {
}
