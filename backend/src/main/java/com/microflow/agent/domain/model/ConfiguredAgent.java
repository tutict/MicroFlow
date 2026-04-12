package com.microflow.agent.domain.model;

public record ConfiguredAgent(
        String agentKey,
        String provider,
        String endpointUrl,
        String credential,
        boolean enabled,
        String roleStrategy
) {
}
