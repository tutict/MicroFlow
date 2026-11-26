package com.microflow.agent.runtime.api.mapper;

import tools.jackson.databind.ObjectMapper;
import com.microflow.agent.runtime.api.dto.AgentApprovalResponse;
import com.microflow.agent.runtime.api.dto.AgentArtifactResponse;
import com.microflow.agent.runtime.api.dto.AgentContextSourceResponse;
import com.microflow.agent.runtime.api.dto.AgentRunEventResponse;
import com.microflow.agent.runtime.api.dto.AgentRunResponse;
import com.microflow.agent.runtime.api.dto.AgentRunStepResponse;
import com.microflow.agent.runtime.api.dto.AgentToolDescriptorResponse;
import com.microflow.agent.runtime.api.dto.AgentToolInvocationResponse;
import com.microflow.agent.runtime.domain.model.AgentApproval;
import com.microflow.agent.runtime.domain.model.AgentArtifact;
import com.microflow.agent.runtime.domain.model.AgentContextSource;
import com.microflow.agent.runtime.domain.model.AgentRunEvent;
import com.microflow.agent.runtime.domain.model.AgentRunSession;
import com.microflow.agent.runtime.domain.model.AgentRunStep;
import com.microflow.agent.runtime.domain.model.AgentToolInvocation;
import com.microflow.agent.runtime.domain.model.ToolDescriptor;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.stereotype.Component;

@Component
public class AgentRuntimeApiMapper {

    private final ObjectMapper objectMapper;

    public AgentRuntimeApiMapper(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    public AgentRunResponse toResponse(AgentRunSession session, String pendingApprovalId) {
        return new AgentRunResponse(
                session.id(),
                session.workspaceId(),
                session.taskId(),
                session.channelId(),
                session.initiatorUserId(),
                session.agentKey(),
                session.runKind(),
                session.status().name(),
                session.goal(),
                session.contextSummary(),
                session.errorMessage(),
                session.interruptionState(),
                session.stepCount(),
                session.approvalWaitCount(),
                session.attemptCount(),
                pendingApprovalId,
                session.createdAt(),
                session.startedAt(),
                session.finishedAt(),
                session.updatedAt()
        );
    }

    public AgentRunEventResponse toResponse(AgentRunEvent event) {
        return new AgentRunEventResponse(
                event.id(),
                event.seq(),
                event.type(),
                readObject(event.payloadJson()),
                event.createdAt()
        );
    }

    public AgentApprovalResponse toResponse(AgentApproval approval) {
        return new AgentApprovalResponse(
                approval.id(),
                approval.sessionId(),
                approval.toolKey(),
                approval.action(),
                approval.targetResource(),
                approval.riskLevel(),
                approval.impactSummary(),
                readObject(approval.inputJson()),
                approval.status().name(),
                approval.decidedByUserId(),
                approval.decisionNote(),
                approval.createdAt(),
                approval.decidedAt()
        );
    }

    public AgentArtifactResponse toResponse(AgentArtifact artifact) {
        return new AgentArtifactResponse(
                artifact.id(),
                artifact.sessionId(),
                artifact.artifactKind(),
                artifact.title(),
                artifact.summary(),
                artifact.contentText(),
                artifact.uri(),
                artifact.createdAt()
        );
    }

    public AgentRunStepResponse toResponse(AgentRunStep step) {
        return new AgentRunStepResponse(
                step.id(),
                step.seq(),
                step.stepKind(),
                step.status(),
                step.agentKey(),
                step.title(),
                step.detail(),
                step.startedAt(),
                step.finishedAt()
        );
    }

    public AgentToolInvocationResponse toResponse(AgentToolInvocation invocation) {
        return new AgentToolInvocationResponse(
                invocation.id(),
                invocation.sessionId(),
                invocation.toolKey(),
                invocation.status().name(),
                invocation.riskLevel(),
                readObject(invocation.inputJson()),
                invocation.outputJson(),
                invocation.errorMessage(),
                invocation.approvalId(),
                invocation.attemptCount(),
                invocation.createdAt(),
                invocation.finishedAt()
        );
    }

    public AgentToolDescriptorResponse toResponse(ToolDescriptor descriptor) {
        return new AgentToolDescriptorResponse(
                descriptor.key(),
                descriptor.title(),
                descriptor.description(),
                descriptor.inputSchema(),
                descriptor.permission().name(),
                descriptor.risk().name(),
                descriptor.idempotent()
        );
    }

    public AgentContextSourceResponse toResponse(AgentContextSource source) {
        return new AgentContextSourceResponse(
                source.id(),
                source.sourceType(),
                source.label(),
                source.refId(),
                source.excerpt()
        );
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> readObject(String json) {
        if (json == null || json.isBlank()) {
            return Map.of();
        }
        try {
            return objectMapper.readValue(json, LinkedHashMap.class);
        } catch (Exception exception) {
            return Map.of();
        }
    }
}
