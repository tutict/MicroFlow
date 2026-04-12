package com.microflow.agent.api.mapper;

import com.microflow.agent.api.dto.AgentDiagnosticResponse;
import com.microflow.agent.api.dto.AgentResponse;
import com.microflow.agent.api.dto.AgentRunResponse;
import com.microflow.agent.domain.model.AgentDiagnostic;
import com.microflow.agent.domain.model.AgentDescriptor;
import com.microflow.agent.domain.model.AgentRunLog;
import org.springframework.stereotype.Component;

@Component
public class AgentApiMapper {

    public AgentResponse toResponse(AgentDescriptor descriptor) {
        return new AgentResponse(
                descriptor.agentKey(),
                descriptor.provider(),
                descriptor.enabled()
        );
    }

    public AgentRunResponse toResponse(AgentRunLog runLog) {
        return new AgentRunResponse(
                runLog.id(),
                runLog.agentKey(),
                runLog.status(),
                runLog.triggerMessageId(),
                runLog.resultMessageId(),
                runLog.createdAt(),
                runLog.finishedAt(),
                runLog.errorMessage()
        );
    }

    public AgentDiagnosticResponse toResponse(AgentDiagnostic diagnostic) {
        return new AgentDiagnosticResponse(
                diagnostic.agentKey(),
                diagnostic.provider(),
                diagnostic.endpointUrl(),
                diagnostic.enabled(),
                diagnostic.credentialConfigured(),
                diagnostic.roleStrategy(),
                diagnostic.status(),
                diagnostic.detail(),
                diagnostic.latencyMillis(),
                diagnostic.checkedAt()
        );
    }
}
