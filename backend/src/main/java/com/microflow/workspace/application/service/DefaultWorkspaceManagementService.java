package com.microflow.workspace.application.service;

import com.microflow.agent.config.DeploymentAgentCatalog;
import com.microflow.auth.infrastructure.persistence.JdbcUserRepository;
import com.microflow.workspace.domain.model.WorkspaceSummary;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import org.springframework.stereotype.Service;

@Service
public class DefaultWorkspaceManagementService implements WorkspaceManagementService {

    private final JdbcWorkspaceRepository workspaceRepository;
    private final DeploymentAgentCatalog deploymentAgentCatalog;
    private final JdbcUserRepository userRepository;

    public DefaultWorkspaceManagementService(
            JdbcWorkspaceRepository workspaceRepository,
            DeploymentAgentCatalog deploymentAgentCatalog,
            JdbcUserRepository userRepository
    ) {
        this.workspaceRepository = workspaceRepository;
        this.deploymentAgentCatalog = deploymentAgentCatalog;
        this.userRepository = userRepository;
    }

    @Override
    public WorkspaceSummary createWorkspace(String userId, String displayName, String requestedName) {
        var normalizedName = requestedName == null ? "" : requestedName.trim();
        if (normalizedName.isBlank()) {
            normalizedName = displayName + "'s Workspace";
        }
        var workspaceId = workspaceRepository.createWorkspace(
                userId,
                normalizedName,
                deploymentAgentCatalog.discover()
        );
        return workspaceRepository.findSummaryById(workspaceId)
                .orElseThrow(() -> new IllegalStateException("Created workspace could not be loaded"));
    }

    @Override
    public void addMemberByEmail(String actorUserId, String workspaceId, String email) {
        if (!workspaceRepository.isWorkspaceOwner(workspaceId, actorUserId)) {
            throw new IllegalArgumentException("Only workspace owners can add members");
        }
        var normalizedEmail = email == null ? "" : email.trim().toLowerCase();
        if (normalizedEmail.isBlank()) {
            throw new IllegalArgumentException("Member email is required");
        }
        var user = userRepository.findByEmail(normalizedEmail)
                .orElseThrow(() -> new IllegalArgumentException("No registered user found for that email"));
        workspaceRepository.addMemberIfAbsent(workspaceId, user.id(), "MEMBER");
    }
}
