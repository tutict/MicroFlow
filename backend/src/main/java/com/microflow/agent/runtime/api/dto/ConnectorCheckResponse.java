package com.microflow.agent.runtime.api.dto;

/** Result of a connectivity check, already persisted on the connector row. */
public record ConnectorCheckResponse(
        String connectorId,
        String status,
        String detail,
        String checkedAt
) {
}
