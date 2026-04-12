package com.microflow.agent.application.service;

import com.microflow.agent.domain.model.AgentDiagnostic;
import com.microflow.agent.domain.model.AgentDescriptor;
import com.microflow.agent.domain.model.AgentRunLog;
import com.microflow.agent.infrastructure.persistence.JdbcAgentRepository;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class DefaultAgentRunService implements AgentRunService {

    static final int MAX_ROLE_STRATEGY_LENGTH = 1000;

    private final JdbcAgentRepository agentRepository;
    private final JdbcWorkspaceRepository workspaceRepository;
    private final AgentDiagnosticsService agentDiagnosticsService;

    public DefaultAgentRunService(
            JdbcAgentRepository agentRepository,
            JdbcWorkspaceRepository workspaceRepository,
            AgentDiagnosticsService agentDiagnosticsService
    ) {
        this.agentRepository = agentRepository;
        this.workspaceRepository = workspaceRepository;
        this.agentDiagnosticsService = agentDiagnosticsService;
    }

    @Override
    public List<AgentDescriptor> listAgents(String userId, String workspaceId) {
        ensureMembership(workspaceId, userId);
        return agentRepository.listAgents(workspaceId);
    }

    @Override
    public List<AgentRunLog> listRuns(String userId, String workspaceId) {
        ensureMembership(workspaceId, userId);
        return agentRepository.listRuns(workspaceId);
    }

    @Override
    public List<AgentDiagnostic> listDiagnostics(String userId, String workspaceId) {
        ensureMembership(workspaceId, userId);
        return agentDiagnosticsService.inspect(workspaceId);
    }

    @Override
    public void updateRoleStrategy(String userId, String workspaceId, String agentKey, String roleStrategy) {
        ensureMembership(workspaceId, userId);
        validateRoleStrategy(roleStrategy);
        agentRepository.updateRoleStrategy(workspaceId, agentKey, roleStrategy);
    }

    private void validateRoleStrategy(String roleStrategy) {
        if (roleStrategy == null) {
            return;
        }
        var normalized = roleStrategy.trim();
        if (normalized.length() > MAX_ROLE_STRATEGY_LENGTH) {
            throw new IllegalArgumentException(
                    "Role strategy must be %s characters or fewer".formatted(MAX_ROLE_STRATEGY_LENGTH)
            );
        }
    }

    private void ensureMembership(String workspaceId, String userId) {
        if (!workspaceRepository.isWorkspaceMember(workspaceId, userId)) {
            throw new IllegalArgumentException("Workspace access denied");
        }
    }
}
