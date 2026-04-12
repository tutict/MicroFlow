package com.microflow.agent.config;

public record DiscoveredAgentBinding(
        String agentKey,
        String provider,
        String endpointUrl,
        String credential
) {
}
