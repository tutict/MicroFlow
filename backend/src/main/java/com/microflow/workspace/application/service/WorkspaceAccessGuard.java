package com.microflow.workspace.application.service;

import com.microflow.workspace.domain.model.WorkspaceRole;

/**
 * Central authorization boundary for workspace-scoped resources.
 *
 * <p>The workspace repositories already expose membership predicates, but before
 * this contract existed no service layer called them, so any authenticated user
 * could read or mutate another workspace's data. Task endpoints depend on this
 * contract instead of querying membership ad hoc.
 */
public interface WorkspaceAccessGuard {

    /** Rejects callers that are not members of the workspace. */
    void requireMember(String workspaceId, String userId);

    /** Rejects callers that are members but not workspace owners. */
    void requireOwner(String workspaceId, String userId);

    /** Rejects callers whose role lacks the given capability. */
    void requireCapability(
            String workspaceId,
            String userId,
            WorkspaceRole.Capability capability
    );

    /** Rejects callers whose role cannot create or close task projects. */
    void requireProjectAdmin(String workspaceId, String userId);

    /**
     * Rejects callers that are neither workspace owners nor the task assignee or
     * creator. Keeps assignment and status changes inside the accountable circle
     * without forcing every change through the owner.
     */
    void requireTaskWriteAccess(String workspaceId, String taskId, String userId);

    /** Rejects callers whose role cannot assign a task to someone else. */
    void requireAssigneeWriteAccess(String workspaceId, String taskId, String userId);

    boolean isMember(String workspaceId, String userId);

    boolean isOwner(String workspaceId, String userId);

    /** Resolves the caller's role, or {@code null} when not a member. */
    WorkspaceRole roleOf(String workspaceId, String userId);
}
