package com.microflow.workspace.infrastructure.security;

import com.microflow.common.error.AccessDeniedException;
import com.microflow.common.error.ResourceNotFoundException;
import com.microflow.workspace.application.service.TaskAccountabilityLookup;
import com.microflow.workspace.application.service.WorkspaceAccessGuard;
import com.microflow.workspace.domain.model.WorkspaceRole;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import org.springframework.stereotype.Service;

@Service
public class DefaultWorkspaceAccessGuard implements WorkspaceAccessGuard {

    private final JdbcWorkspaceRepository workspaceRepository;
    private final TaskAccountabilityLookup accountabilityLookup;

    public DefaultWorkspaceAccessGuard(
            JdbcWorkspaceRepository workspaceRepository,
            TaskAccountabilityLookup accountabilityLookup
    ) {
        this.workspaceRepository = workspaceRepository;
        this.accountabilityLookup = accountabilityLookup;
    }

    @Override
    public void requireMember(String workspaceId, String userId) {
        if (workspaceId == null || workspaceId.isBlank()) {
            throw new IllegalArgumentException("workspaceId is required");
        }
        if (userId == null || userId.isBlank()) {
            throw new AccessDeniedException("Missing authenticated user");
        }
        if (!workspaceRepository.isWorkspaceMember(workspaceId, userId)) {
            throw new AccessDeniedException("Not a member of workspace " + workspaceId);
        }
    }

    @Override
    public void requireOwner(String workspaceId, String userId) {
        requireMember(workspaceId, userId);
        if (!workspaceRepository.isWorkspaceOwner(workspaceId, userId)) {
            throw new AccessDeniedException("Workspace owner role required");
        }
    }

    @Override
    public void requireCapability(
            String workspaceId,
            String userId,
            WorkspaceRole.Capability capability
    ) {
        requireMember(workspaceId, userId);
        var role = workspaceRepository.findRole(workspaceId, userId);
        if (!role.can(capability)) {
            throw new AccessDeniedException(
                    "Role " + role.storedValue() + " lacks capability " + capability);
        }
    }

    @Override
    public void requireProjectAdmin(String workspaceId, String userId) {
        requireCapability(workspaceId, userId, WorkspaceRole.Capability.CREATE_PROJECT);
    }

    @Override
    public void requireTaskWriteAccess(String workspaceId, String taskId, String userId) {
        requireCapability(workspaceId, userId, WorkspaceRole.Capability.CREATE_TASK);
        var accountable = accountabilityLookup.find(workspaceId, taskId);
        if (accountable == null) {
            throw new ResourceNotFoundException("Task not found: " + taskId);
        }
        var role = workspaceRepository.findRole(workspaceId, userId);
        if (role.can(WorkspaceRole.Capability.ADVANCE_ANY_TASK)) {
            return;
        }
        if (!accountable.involves(userId)) {
            throw new AccessDeniedException(
                    "Only a maintainer, the assignee or the creator may modify task " + taskId);
        }
    }

    @Override
    public void requireAssigneeWriteAccess(String workspaceId, String taskId, String userId) {
        requireCapability(workspaceId, userId, WorkspaceRole.Capability.CREATE_TASK);
        var accountable = accountabilityLookup.find(workspaceId, taskId);
        if (accountable == null) {
            throw new ResourceNotFoundException("Task not found: " + taskId);
        }
        var role = workspaceRepository.findRole(workspaceId, userId);
        if (role.can(WorkspaceRole.Capability.ASSIGN_ANY_TASK)) {
            return;
        }
        if (!accountable.involves(userId)) {
            throw new AccessDeniedException(
                    "Only a maintainer, the assignee or the creator may reassign task " + taskId);
        }
    }

    @Override
    public WorkspaceRole roleOf(String workspaceId, String userId) {
        if (workspaceId == null || userId == null) {
            return null;
        }
        return workspaceRepository.findRoleOrNull(workspaceId, userId);
    }

    @Override
    public boolean isMember(String workspaceId, String userId) {
        return workspaceId != null && userId != null
                && workspaceRepository.isWorkspaceMember(workspaceId, userId);
    }

    @Override
    public boolean isOwner(String workspaceId, String userId) {
        return workspaceId != null && userId != null
                && workspaceRepository.isWorkspaceOwner(workspaceId, userId);
    }
}
