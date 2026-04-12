package com.microflow.agent.infrastructure.provider.openclaw;

import com.microflow.agent.domain.gateway.AgentGateway;
import com.microflow.agent.domain.model.AgentExecutionRequest;
import com.microflow.agent.domain.model.AgentExecutionResult;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class MockOpenClawAgentGateway implements AgentGateway {

    private final Duration responseDelay;

    public MockOpenClawAgentGateway(@Value("${microflow.agent.mock-delay:PT0.6S}") Duration responseDelay) {
        this.responseDelay = responseDelay;
    }

    @Override
    public AgentExecutionResult execute(AgentExecutionRequest request) {
        try {
            Thread.sleep(responseDelay);
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            return new AgentExecutionResult(false, null, "Agent execution interrupted");
        }
        var output = "[" + request.agentKey() + "] " +
                "Processed request for channel " + request.channelId() + ": " + request.prompt();
        return new AgentExecutionResult(true, output, null);
    }
}
