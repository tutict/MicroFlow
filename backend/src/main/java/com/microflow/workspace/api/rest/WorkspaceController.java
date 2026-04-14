package com.microflow.workspace.api.rest;

import com.microflow.workspace.api.dto.ChannelSummaryResponse;
import com.microflow.workspace.api.dto.ConversationSummaryResponse;
import com.microflow.workspace.api.dto.AddWorkspaceMemberRequest;
import com.microflow.workspace.api.dto.CreateWorkspaceRequest;
import com.microflow.workspace.api.dto.WorkspaceMemberSummaryResponse;
import com.microflow.workspace.api.dto.WorkspaceSummaryResponse;
import com.microflow.workspace.api.mapper.WorkspaceApiMapper;
import com.microflow.workspace.application.service.WorkspaceManagementService;
import com.microflow.workspace.application.service.WorkspaceQueryService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class WorkspaceController {

    private final WorkspaceQueryService workspaceQueryService;
    private final WorkspaceManagementService workspaceManagementService;
    private final WorkspaceApiMapper workspaceApiMapper;

    public WorkspaceController(
            WorkspaceQueryService workspaceQueryService,
            WorkspaceManagementService workspaceManagementService,
            WorkspaceApiMapper workspaceApiMapper
    ) {
        this.workspaceQueryService = workspaceQueryService;
        this.workspaceManagementService = workspaceManagementService;
        this.workspaceApiMapper = workspaceApiMapper;
    }

    @GetMapping("/workspaces")
    public List<WorkspaceSummaryResponse> listWorkspaces(HttpServletRequest request) {
        var userId = (String) request.getAttribute("currentUserId");
        return workspaceQueryService.listWorkspaces(userId).stream()
                .map(workspaceApiMapper::toResponse)
                .toList();
    }

    @PostMapping("/workspaces")
    public WorkspaceSummaryResponse createWorkspace(
            @Valid @RequestBody CreateWorkspaceRequest request,
            HttpServletRequest httpRequest
    ) {
        var userId = (String) httpRequest.getAttribute("currentUserId");
        var displayName = (String) httpRequest.getAttribute("currentDisplayName");
        return workspaceApiMapper.toResponse(
                workspaceManagementService.createWorkspace(userId, displayName, request.name())
        );
    }

    @GetMapping("/workspaces/{workspaceId}/members")
    public List<WorkspaceMemberSummaryResponse> listMembers(
            @PathVariable String workspaceId,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return workspaceQueryService.listMembers(userId, workspaceId).stream()
                .map(workspaceApiMapper::toResponse)
                .toList();
    }

    @PostMapping("/workspaces/{workspaceId}/members")
    public List<WorkspaceMemberSummaryResponse> addMember(
            @PathVariable String workspaceId,
            @Valid @RequestBody AddWorkspaceMemberRequest request,
            HttpServletRequest httpRequest
    ) {
        var userId = (String) httpRequest.getAttribute("currentUserId");
        workspaceManagementService.addMemberByEmail(userId, workspaceId, request.email());
        return workspaceQueryService.listMembers(userId, workspaceId).stream()
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
