package com.microflow.agent.application.service;

import com.microflow.agent.domain.model.AgentDiagnostic;
import com.microflow.agent.domain.model.AgentDescriptor;
import com.microflow.agent.domain.model.AgentRunLog;
import java.util.List;

public interface AgentRunService {

    List<AgentDescriptor> listAgents(String userId, String workspaceId);

    List<AgentRunLog> listRuns(String userId, String workspaceId);

    List<AgentDiagnostic> listDiagnostics(String userId, String workspaceId);

    void updateRoleStrategy(String userId, String workspaceId, String agentKey, String roleStrategy);
}
