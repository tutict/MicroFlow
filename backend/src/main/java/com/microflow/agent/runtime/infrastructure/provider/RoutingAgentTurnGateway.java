package com.microflow.agent.runtime.infrastructure.provider;

import com.microflow.agent.domain.model.AgentExecutionTarget;
import com.microflow.agent.infrastructure.persistence.JdbcAgentRepository;
import com.microflow.agent.runtime.domain.gateway.AgentTurnGateway;
import com.microflow.agent.runtime.domain.gateway.AgentTurnRequest;
import com.microflow.agent.runtime.domain.gateway.AgentTurnResult;
import com.microflow.agent.runtime.domain.gateway.ProviderCapability;
import java.time.Instant;
import org.springframework.stereotype.Component;

/** Dispatches structured turns to the provider bound to the agent. */
@Component
public class RoutingAgentTurnGateway implements AgentTurnGateway {

    private final JdbcAgentRepository agentRepository;
    private final MockAgentTurnGateway mockAgentTurnGateway;
    private final OpenClawTurnGateway openClawTurnGateway;

    public RoutingAgentTurnGateway(
            JdbcAgentRepository agentRepository,
            MockAgentTurnGateway mockAgentTurnGateway,
            OpenClawTurnGateway openClawTurnGateway
    ) {
        this.agentRepository = agentRepository;
        this.mockAgentTurnGateway = mockAgentTurnGateway;
        this.openClawTurnGateway = openClawTurnGateway;
    }

    @Override
    public AgentTurnResult turn(AgentTurnRequest request) {
        var target = agentRepository.findExecutionTarget(request.workspaceId(), request.agentKey());
        if (target == null) {
            return AgentTurnResult.failed("Agent is not configured: " + request.agentKey());
        }
        var provider = normalize(target.provider());
        if ("mock-openclaw".equals(provider)) {
            return mockAgentTurnGateway.turn(request);
        }
        if (provider.contains("claw")) {
            return openClawTurnGateway.turn(request, target);
        }
        return AgentTurnResult.failed("Unsupported agent provider: " + target.provider());
    }

    @Override
    public ProviderCapability detectCapability(String workspaceId, String agentKey) {
        var target = agentRepository.findExecutionTarget(workspaceId, agentKey);
        if (target == null) {
            return ProviderCapability.unsupported(
                    "Agent is not configured: " + agentKey, Instant.now().toString());
        }
        var provider = normalize(target.provider());
        if ("mock-openclaw".equals(provider)) {
            return mockAgentTurnGateway.detectCapability(workspaceId, agentKey);
        }
        if (provider.contains("claw")) {
            return openClawTurnGateway.detectCapability(agentKey, target);
        }
        return ProviderCapability.unsupported(
                "Unsupported agent provider: " + target.provider(), Instant.now().toString());
    }

    private String normalize(String provider) {
        return provider == null ? "" : provider.trim().toLowerCase(java.util.Locale.ROOT);
    }
}
