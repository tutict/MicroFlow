package com.microflow.agent.runtime.api.rest;

import com.microflow.agent.runtime.api.dto.AgentApprovalResponse;
import com.microflow.agent.runtime.api.dto.AgentArtifactResponse;
import com.microflow.agent.runtime.api.dto.AgentContextSourceResponse;
import com.microflow.agent.runtime.api.dto.AgentRunEventResponse;
import com.microflow.agent.runtime.api.dto.AgentRunResponse;
import com.microflow.agent.runtime.api.dto.AgentRunStepResponse;
import com.microflow.agent.runtime.api.dto.AgentToolDescriptorResponse;
import com.microflow.agent.runtime.api.dto.AgentToolInvocationResponse;
import com.microflow.agent.runtime.api.dto.DecideApprovalRequest;
import com.microflow.agent.runtime.api.dto.StartAgentRunRequest;
import com.microflow.agent.runtime.api.mapper.AgentRuntimeApiMapper;
import com.microflow.agent.runtime.application.AgentRuntimeService;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class AgentRunController {

    private final AgentRuntimeService runtimeService;
    private final AgentRuntimeApiMapper mapper;

    public AgentRunController(AgentRuntimeService runtimeService, AgentRuntimeApiMapper mapper) {
        this.runtimeService = runtimeService;
        this.mapper = mapper;
    }

    @PostMapping("/workspaces/{workspaceId}/tasks/{taskId}/agent-runs")
    public AgentRunResponse startTaskRun(
            @PathVariable String workspaceId,
            @PathVariable String taskId,
            @RequestBody(required = false) StartAgentRunRequest body,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        var safeBody = body == null ? new StartAgentRunRequest(null, null) : body;
        var session = runtimeService.startTaskRun(
                userId, workspaceId, taskId, safeBody.agentKey(), safeBody.goal());
        return mapper.toResponse(session, null);
    }

    @GetMapping("/workspaces/{workspaceId}/agent-runs")
    public List<AgentRunResponse> listRuns(
            @PathVariable String workspaceId,
            HttpServletRequest request,
            @RequestParam(required = false) String taskId,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "false") boolean activeOnly,
            @RequestParam(required = false) String afterId,
            @RequestParam(defaultValue = "50") int limit
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        var sessions = runtimeService.listRuns(userId, workspaceId, taskId, status, limit, activeOnly, afterId);
        var pending = runtimeService.pendingApprovalIds(userId, workspaceId);
        return sessions.stream()
                .map(session -> mapper.toResponse(session, pending.get(session.id())))
                .toList();
    }

    @GetMapping("/agent-runs/{runId}")
    public AgentRunResponse getRun(@PathVariable String runId, HttpServletRequest request) {
        var userId = (String) request.getAttribute("currentUserId");
        var session = runtimeService.findRun(userId, runId);
        var pending = runtimeService.pendingApproval(runId).map(approval -> approval.id()).orElse(null);
        return mapper.toResponse(session, pending);
    }

    @GetMapping("/agent-runs/{runId}/events")
    public List<AgentRunEventResponse> listEvents(
            @PathVariable String runId,
            HttpServletRequest request,
            @RequestParam(defaultValue = "0") long afterSeq,
            @RequestParam(defaultValue = "200") int limit
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return runtimeService.listEvents(userId, runId, afterSeq, limit).stream()
                .map(mapper::toResponse)
                .toList();
    }

    @GetMapping("/agent-runs/{runId}/steps")
    public List<AgentRunStepResponse> listSteps(@PathVariable String runId, HttpServletRequest request) {
        var userId = (String) request.getAttribute("currentUserId");
        return runtimeService.listSteps(userId, runId).stream()
                .map(mapper::toResponse)
                .toList();
    }

    @GetMapping("/agent-runs/{runId}/context-sources")
    public List<AgentContextSourceResponse> listContextSources(
            @PathVariable String runId,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return runtimeService.listContextSources(userId, runId).stream()
                .map(mapper::toResponse)
                .toList();
    }

    @GetMapping("/agent-runs/{runId}/approvals")
    public List<AgentApprovalResponse> listApprovals(
            @PathVariable String runId,
            HttpServletRequest request,
            @RequestParam(required = false) String status
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return runtimeService.listApprovals(userId, runId, status).stream()
                .map(mapper::toResponse)
                .toList();
    }

    @GetMapping("/agent-runs/{runId}/artifacts")
    public List<AgentArtifactResponse> listArtifacts(
            @PathVariable String runId,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return runtimeService.listArtifacts(userId, runId).stream()
                .map(mapper::toResponse)
                .toList();
    }

    @GetMapping("/agent-runs/{runId}/tool-invocations")
    public List<AgentToolInvocationResponse> listInvocations(
            @PathVariable String runId,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return runtimeService.listInvocations(userId, runId).stream()
                .map(mapper::toResponse)
                .toList();
    }

    @PostMapping("/agent-runs/{runId}/approvals/{approvalId}/decision")
    public AgentApprovalResponse decideApproval(
            @PathVariable String runId,
            @PathVariable String approvalId,
            @RequestBody DecideApprovalRequest body,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        var approval = runtimeService.decideApproval(
                userId, runId, approvalId, body.decision(), body.note());
        return mapper.toResponse(approval);
    }

    @PostMapping("/agent-runs/{runId}/cancel")
    public AgentRunResponse cancel(@PathVariable String runId, HttpServletRequest request) {
        var userId = (String) request.getAttribute("currentUserId");
        var session = runtimeService.cancel(userId, runId);
        return mapper.toResponse(session, null);
    }

    @PostMapping("/agent-runs/{runId}/retry")
    public AgentRunResponse retry(@PathVariable String runId, HttpServletRequest request) {
        var userId = (String) request.getAttribute("currentUserId");
        var session = runtimeService.retry(userId, runId);
        return mapper.toResponse(session, null);
    }

    @GetMapping("/agent-tools")
    public List<AgentToolDescriptorResponse> listTools(HttpServletRequest request) {
        // Tool declarations are static and contain no workspace data.
        return runtimeService.toolCatalog().stream().map(mapper::toResponse).toList();
    }
}
