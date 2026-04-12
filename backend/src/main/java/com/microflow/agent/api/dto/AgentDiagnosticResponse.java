package com.microflow.agent.api.dto;

public record AgentDiagnosticResponse(
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
