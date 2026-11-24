package com.microflow.agent.runtime.api.rest;

import com.microflow.agent.runtime.api.dto.ConnectorCheckResponse;
import com.microflow.agent.runtime.api.dto.ConnectorResponse;
import com.microflow.agent.runtime.api.dto.UpsertConnectorRequest;
import com.microflow.agent.runtime.api.mapper.ConnectorApiMapper;
import com.microflow.agent.runtime.application.ConnectorService;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Connector settings endpoints.
 *
 * <p>Every response passes through {@link ConnectorApiMapper}, which only ever
 * exposes secret <em>field names</em>. There is deliberately no endpoint that
 * returns a stored password: re-reading a credential is not a feature this
 * product needs, and supporting it would put the secret on the wire a second
 * time for no benefit.
 */
@RestController
@RequestMapping("/api/v1")
public class ConnectorController {

    private final ConnectorService connectorService;
    private final ConnectorApiMapper mapper;

    public ConnectorController(ConnectorService connectorService, ConnectorApiMapper mapper) {
        this.connectorService = connectorService;
        this.mapper = mapper;
    }

    @GetMapping("/workspaces/{workspaceId}/connectors")
    public List<ConnectorResponse> list(
            @PathVariable String workspaceId,
            HttpServletRequest request
    ) {
        var userId = currentUser(request);
        return connectorService.list(userId, workspaceId).stream()
                .map(connector -> mapper.toResponse(connector, userId))
                .toList();
    }

    @PostMapping("/workspaces/{workspaceId}/connectors")
    @ResponseStatus(HttpStatus.CREATED)
    public ConnectorResponse create(
            @PathVariable String workspaceId,
            @RequestBody UpsertConnectorRequest body,
            HttpServletRequest request
    ) {
        var userId = currentUser(request);
        var created = connectorService.create(userId, workspaceId, toCommand(body));
        return mapper.toResponse(created, userId);
    }

    @PutMapping("/workspaces/{workspaceId}/connectors/{connectorId}")
    public ConnectorResponse update(
            @PathVariable String workspaceId,
            @PathVariable String connectorId,
            @RequestBody UpsertConnectorRequest body,
            HttpServletRequest request
    ) {
        var userId = currentUser(request);
        var updated = connectorService.update(userId, workspaceId, connectorId, toCommand(body));
        return mapper.toResponse(updated, userId);
    }

    @DeleteMapping("/workspaces/{workspaceId}/connectors/{connectorId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(
            @PathVariable String workspaceId,
            @PathVariable String connectorId,
            HttpServletRequest request
    ) {
        connectorService.delete(currentUser(request), workspaceId, connectorId);
    }

    @PostMapping("/workspaces/{workspaceId}/connectors/{connectorId}/test")
    public ConnectorCheckResponse test(
            @PathVariable String workspaceId,
            @PathVariable String connectorId,
            HttpServletRequest request
    ) {
        return mapper.toResponse(
                connectorService.test(currentUser(request), workspaceId, connectorId));
    }

    private static ConnectorService.ConnectorCommand toCommand(UpsertConnectorRequest body) {
        return new ConnectorService.ConnectorCommand(
                body.kind(),
                body.name(),
                body.config(),
                body.secrets(),
                body.sharingScope(),
                body.sharedUserIds(),
                body.sharedAgentKeys(),
                body.readEnabled(),
                body.writeEnabled()
        );
    }

    private static String currentUser(HttpServletRequest request) {
        return (String) request.getAttribute("currentUserId");
    }
}
