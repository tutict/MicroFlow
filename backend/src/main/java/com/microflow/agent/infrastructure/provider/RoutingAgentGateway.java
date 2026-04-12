package com.microflow.agent.infrastructure.provider;

import com.microflow.agent.domain.gateway.AgentGateway;
import com.microflow.agent.domain.model.AgentExecutionRequest;
import com.microflow.agent.domain.model.AgentExecutionResult;
import com.microflow.agent.infrastructure.persistence.JdbcAgentRepository;
import com.microflow.agent.infrastructure.provider.openclaw.MockOpenClawAgentGateway;
import com.microflow.agent.infrastructure.provider.openclaw.OpenClawHttpAgentGateway;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;

@Component
@Primary
public class RoutingAgentGateway implements AgentGateway {

    private final JdbcAgentRepository agentRepository;
    private final MockOpenClawAgentGateway mockOpenClawAgentGateway;
    private final OpenClawHttpAgentGateway openClawHttpAgentGateway;

    public RoutingAgentGateway(
            JdbcAgentRepository agentRepository,
            MockOpenClawAgentGateway mockOpenClawAgentGateway,
            OpenClawHttpAgentGateway openClawHttpAgentGateway
    ) {
        this.agentRepository = agentRepository;
        this.mockOpenClawAgentGateway = mockOpenClawAgentGateway;
        this.openClawHttpAgentGateway = openClawHttpAgentGateway;
    }

    @Override
    public AgentExecutionResult execute(AgentExecutionRequest request) {
        var target = agentRepository.findExecutionTarget(request.workspaceId(), request.agentKey());
        if (target == null) {
            return new AgentExecutionResult(false, null, "Agent is not configured");
        }

        var provider = target.provider() == null ? "" : target.provider().trim().toLowerCase();
        if ("mock-openclaw".equals(provider)) {
            return mockOpenClawAgentGateway.execute(request);
        }
        if (provider.contains("claw")) {
            return openClawHttpAgentGateway.execute(request, target);
        }
        return new AgentExecutionResult(false, null, "Unsupported agent provider: " + target.provider());
    }
}
