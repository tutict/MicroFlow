package com.microflow.agent.domain.model;

public record AgentExecutionResult(
        boolean success,
        String output,
        String errorMessage
) {
}

