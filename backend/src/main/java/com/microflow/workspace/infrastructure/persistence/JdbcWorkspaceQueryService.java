package com.microflow.workspace.infrastructure.persistence;

import com.microflow.workspace.application.service.WorkspaceQueryService;
import com.microflow.workspace.domain.model.ChannelSummary;
import com.microflow.workspace.domain.model.ConversationSummary;
import com.microflow.workspace.domain.model.WorkspaceSummary;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class JdbcWorkspaceQueryService implements WorkspaceQueryService {

    private final JdbcWorkspaceRepository workspaceRepository;

    public JdbcWorkspaceQueryService(JdbcWorkspaceRepository workspaceRepository) {
        this.workspaceRepository = workspaceRepository;
    }

    @Override
    public List<WorkspaceSummary> listWorkspaces(String userId) {
        return workspaceRepository.findByUserId(userId);
    }

    @Override
    public List<ChannelSummary> listChannels(String userId, String workspaceId) {
        return workspaceRepository.findChannels(workspaceId, userId);
    }

    @Override
    public List<ConversationSummary> listConversations(String userId, String workspaceId) {
        return workspaceRepository.findConversations(workspaceId, userId);
    }
}
