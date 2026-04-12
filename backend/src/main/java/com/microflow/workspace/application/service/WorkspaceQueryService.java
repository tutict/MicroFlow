package com.microflow.workspace.application.service;

import com.microflow.workspace.domain.model.ChannelSummary;
import com.microflow.workspace.domain.model.ConversationSummary;
import com.microflow.workspace.domain.model.WorkspaceSummary;
import java.util.List;

public interface WorkspaceQueryService {

    List<WorkspaceSummary> listWorkspaces(String userId);

    List<ChannelSummary> listChannels(String userId, String workspaceId);

    List<ConversationSummary> listConversations(String userId, String workspaceId);
}
