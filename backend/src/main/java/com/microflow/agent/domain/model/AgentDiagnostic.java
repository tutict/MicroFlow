package com.microflow.agent.domain.model;

public record AgentDiagnostic(
        String agentKey,
        String provider,
        String endpointUrl,
        boolean enabled,
        boolean credentialConfigured,
        String roleStrategy,
        String status,
        String detail,
        long latencyMillis,
        String checkedAt
) {
}
