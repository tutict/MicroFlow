package com.microflow.workspace.application.service;

import com.microflow.workspace.domain.model.WorkspaceMemberSummary;
import com.microflow.workspace.domain.model.WorkspaceSummary;

public interface WorkspaceManagementService {

    WorkspaceSummary createWorkspace(String userId, String displayName, String requestedName);

    void addMemberByEmail(String actorUserId, String workspaceId, String email);

    WorkspaceMemberSummary changeMemberRole(
            String actorUserId,
            String workspaceId,
            String targetUserId,
            String requestedRole
    );
}
