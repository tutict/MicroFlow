package com.microflow.agent.runtime.domain.gateway;

/** Structured provider port used by the runtime loop. */
public interface AgentTurnGateway {

    AgentTurnResult turn(AgentTurnRequest request);

    /**
     * Detects whether the configured provider for this agent accepts tool
     * declarations. Implementations must be conservative: anything other than a
     * confirmed structured response disables tools for the run.
     */
    ProviderCapability detectCapability(String workspaceId, String agentKey);
}
