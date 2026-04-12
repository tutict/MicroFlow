package com.microflow.agent.domain.model;

public record AgentExecutionTarget(
        String provider,
        String endpointUrl,
        String credential
) {
}
