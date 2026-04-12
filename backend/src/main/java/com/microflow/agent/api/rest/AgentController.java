package com.microflow.agent.api.rest;

import com.microflow.agent.api.dto.AgentDiagnosticResponse;
import com.microflow.agent.api.dto.AgentResponse;
import com.microflow.agent.api.dto.AgentRunResponse;
import com.microflow.agent.api.dto.UpdateAgentRoleStrategyRequest;
import com.microflow.agent.api.mapper.AgentApiMapper;
import com.microflow.agent.application.service.AgentRunService;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class AgentController {

    private final AgentRunService agentRunService;
    private final AgentApiMapper agentApiMapper;

    public AgentController(AgentRunService agentRunService, AgentApiMapper agentApiMapper) {
        this.agentRunService = agentRunService;
        this.agentApiMapper = agentApiMapper;
    }

    @GetMapping("/agents")
    public List<AgentResponse> listAgents(
            @RequestParam String workspaceId,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return agentRunService.listAgents(userId, workspaceId).stream()
                .map(agentApiMapper::toResponse)
                .toList();
    }

    @GetMapping("/agent-runs")
    public List<AgentRunResponse> listRuns(
            @RequestParam String workspaceId,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return agentRunService.listRuns(userId, workspaceId).stream()
                .map(agentApiMapper::toResponse)
                .toList();
    }

    @GetMapping("/agent-diagnostics")
    public List<AgentDiagnosticResponse> listDiagnostics(
            @RequestParam String workspaceId,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return agentRunService.listDiagnostics(userId, workspaceId).stream()
                .map(agentApiMapper::toResponse)
                .toList();
    }

    @PutMapping("/agents/{agentKey}/role-strategy")
    public void updateRoleStrategy(
            @PathVariable String agentKey,
            @RequestParam String workspaceId,
            @RequestBody UpdateAgentRoleStrategyRequest body,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        agentRunService.updateRoleStrategy(userId, workspaceId, agentKey, body == null ? null : body.roleStrategy());
    }
}
