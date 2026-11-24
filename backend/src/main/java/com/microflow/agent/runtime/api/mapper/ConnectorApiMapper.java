package com.microflow.agent.runtime.api.mapper;

import com.microflow.agent.runtime.api.dto.ConnectorCheckResponse;
import com.microflow.agent.runtime.api.dto.ConnectorResponse;
import com.microflow.agent.runtime.application.ConnectorService;
import com.microflow.agent.runtime.domain.model.AgentConnector;
import org.springframework.stereotype.Component;

@Component
public class ConnectorApiMapper {

    public ConnectorResponse toResponse(AgentConnector connector, String currentUserId) {
        return new ConnectorResponse(
                connector.id(),
                connector.workspaceId(),
                connector.ownerUserId(),
                connector.ownerUserId().equals(currentUserId),
                connector.kind().name(),
                connector.name(),
                connector.config(),
                connector.secretFields(),
                connector.sharingScope().name(),
                connector.sharedUserIds(),
                connector.sharedAgentKeys(),
                connector.status().name(),
                connector.readEnabled(),
                connector.writeEnabled(),
                connector.lastError(),
                connector.lastCheckedAt(),
                connector.createdAt(),
                connector.updatedAt()
        );
    }

    public ConnectorCheckResponse toResponse(ConnectorService.ConnectorCheck check) {
        return new ConnectorCheckResponse(
                check.connectorId(),
                check.status().name(),
                check.detail(),
                check.checkedAt()
        );
    }
}
