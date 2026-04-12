package com.microflow.workspace.api.rest;

import com.microflow.workspace.api.dto.ChannelSummaryResponse;
import com.microflow.workspace.api.dto.ConversationSummaryResponse;
import com.microflow.workspace.api.dto.WorkspaceSummaryResponse;
import com.microflow.workspace.api.mapper.WorkspaceApiMapper;
import com.microflow.workspace.application.service.WorkspaceQueryService;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class WorkspaceController {

    private final WorkspaceQueryService workspaceQueryService;
    private final WorkspaceApiMapper workspaceApiMapper;

    public WorkspaceController(WorkspaceQueryService workspaceQueryService, WorkspaceApiMapper workspaceApiMapper) {
        this.workspaceQueryService = workspaceQueryService;
        this.workspaceApiMapper = workspaceApiMapper;
    }

    @GetMapping("/workspaces")
    public List<WorkspaceSummaryResponse> listWorkspaces(HttpServletRequest request) {
        var userId = (String) request.getAttribute("currentUserId");
        return workspaceQueryService.listWorkspaces(userId).stream()
                .map(workspaceApiMapper::toResponse)
                .toList();
    }

    @GetMapping("/workspaces/{workspaceId}/channels")
    public List<ChannelSummaryResponse> listChannels(@PathVariable String workspaceId, HttpServletRequest request) {
        var userId = (String) request.getAttribute("currentUserId");
        return workspaceQueryService.listChannels(userId, workspaceId).stream()
                .map(workspaceApiMapper::toResponse)
                .toList();
    }

    @GetMapping("/workspaces/{workspaceId}/conversations")
    public List<ConversationSummaryResponse> listConversations(
            @PathVariable String workspaceId,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return workspaceQueryService.listConversations(userId, workspaceId).stream()
                .map(workspaceApiMapper::toResponse)
                .toList();
    }
}
