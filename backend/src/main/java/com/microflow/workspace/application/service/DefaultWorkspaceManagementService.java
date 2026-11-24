package com.microflow.workspace.application.service;

import com.microflow.agent.config.DeploymentAgentCatalog;
import com.microflow.auth.infrastructure.persistence.JdbcUserRepository;
import com.microflow.common.error.AccessDeniedException;
import com.microflow.common.error.ConcurrentModificationException;
import com.microflow.common.error.ResourceNotFoundException;
import com.microflow.workspace.domain.model.WorkspaceMemberSummary;
import com.microflow.workspace.domain.model.WorkspaceRole;
import com.microflow.workspace.domain.model.WorkspaceSummary;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import org.springframework.stereotype.Service;

@Service
public class DefaultWorkspaceManagementService implements WorkspaceManagementService {

    private final JdbcWorkspaceRepository workspaceRepository;
    private final DeploymentAgentCatalog deploymentAgentCatalog;
    private final JdbcUserRepository userRepository;
    private final WorkspaceAccessGuard accessGuard;

    public DefaultWorkspaceManagementService(
            JdbcWorkspaceRepository workspaceRepository,
            DeploymentAgentCatalog deploymentAgentCatalog,
            JdbcUserRepository userRepository,
            WorkspaceAccessGuard accessGuard
    ) {
        this.workspaceRepository = workspaceRepository;
        this.deploymentAgentCatalog = deploymentAgentCatalog;
        this.userRepository = userRepository;
        this.accessGuard = accessGuard;
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
        accessGuard.requireCapability(
                workspaceId, actorUserId, WorkspaceRole.Capability.MANAGE_ROLES);
        var normalizedEmail = email == null ? "" : email.trim().toLowerCase();
        if (normalizedEmail.isBlank()) {
            throw new IllegalArgumentException("Member email is required");
        }
        var user = userRepository.findByEmail(normalizedEmail)
                .orElseThrow(() -> new IllegalArgumentException("No registered user found for that email"));
        workspaceRepository.addMemberIfAbsent(
                workspaceId, user.id(), WorkspaceRole.OPERATOR.storedValue());
    }

    @Override
    public WorkspaceMemberSummary changeMemberRole(
            String actorUserId,
            String workspaceId,
            String targetUserId,
            String requestedRole
    ) {
        accessGuard.requireCapability(
                workspaceId, actorUserId, WorkspaceRole.Capability.MANAGE_ROLES);
        if (targetUserId == null || targetUserId.isBlank()) {
            throw new IllegalArgumentException("Target user id is required");
        }
        var targetRole = WorkspaceRole.parseRequested(requestedRole);
        if (targetRole == null) {
            throw new IllegalArgumentException(
                    "Unknown role: " + requestedRole + "; expected one of "
                            + WorkspaceRole.allStoredValues());
        }
        var actorRole = workspaceRepository.findRole(workspaceId, actorUserId);
        var currentRole = workspaceRepository.findRoleOrNull(workspaceId, targetUserId);
        if (currentRole == null) {
            throw new ResourceNotFoundException(
                    "User " + targetUserId + " is not a member of this workspace");
        }
        if (!actorRole.canManageRole(currentRole)) {
            throw new AccessDeniedException(
                    "Role " + actorRole.storedValue() + " cannot change a "
                            + currentRole.storedValue() + " member");
        }
        if (currentRole == WorkspaceRole.OWNER && targetRole != WorkspaceRole.OWNER
                && actorUserId.equals(targetUserId)) {
            throw new IllegalArgumentException("You cannot demote yourself; ask another owner");
        }
        if (currentRole == WorkspaceRole.OWNER && targetRole != WorkspaceRole.OWNER
                && !workspaceRepository.hasAnotherOwner(workspaceId, targetUserId)) {
            // Keep the ordinary validation error, while a revoked actor is forbidden.
            accessGuard.requireCapability(
                    workspaceId, actorUserId, WorkspaceRole.Capability.MANAGE_ROLES);
            throw new IllegalArgumentException(
                    "A workspace must keep at least one owner; promote another member first");
        }
        // The snapshots above provide validation messages; only this SQL can authorize
        // and apply the change. Even a no-op must reject a stale target or revoked actor.
        if (!workspaceRepository.updateMemberRoleAtomically(
                workspaceId, actorUserId, targetUserId, currentRole, targetRole)) {
            throw new ConcurrentModificationException(
                    "Workspace roles changed; reload the members before changing a role");
        }
        return requireMember(workspaceId, targetUserId);
    }

    private WorkspaceMemberSummary requireMember(String workspaceId, String targetUserId) {
        return workspaceRepository.findMembers(workspaceId, targetUserId).stream()
                .filter(member -> member.userId().equals(targetUserId))
                .findFirst()
                .orElseThrow(() -> new ResourceNotFoundException(
                        "User " + targetUserId + " is not a member of this workspace"));
    }
}
