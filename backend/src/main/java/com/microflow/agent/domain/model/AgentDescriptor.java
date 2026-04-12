package com.microflow.agent.domain.model;

public record AgentDescriptor(
        String agentKey,
        String provider,
        boolean enabled
) {
}

