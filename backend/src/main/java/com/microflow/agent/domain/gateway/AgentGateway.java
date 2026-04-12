package com.microflow.agent.domain.gateway;

import com.microflow.agent.domain.model.AgentExecutionRequest;
import com.microflow.agent.domain.model.AgentExecutionResult;

public interface AgentGateway {

    AgentExecutionResult execute(AgentExecutionRequest request);
}

