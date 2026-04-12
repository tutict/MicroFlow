package com.microflow.agent.application.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.microflow.agent.domain.model.AgentDiagnostic;
import com.microflow.agent.domain.model.ConfiguredAgent;
import com.microflow.agent.infrastructure.persistence.JdbcAgentRepository;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class AgentDiagnosticsService {

    private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(3);
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(5);

    private final JdbcAgentRepository agentRepository;
    private final HttpClient httpClient;
    private final ObjectMapper objectMapper;

    @Autowired
    public AgentDiagnosticsService(JdbcAgentRepository agentRepository, ObjectMapper objectMapper) {
        this(
                agentRepository,
                HttpClient.newBuilder().connectTimeout(CONNECT_TIMEOUT).build(),
                objectMapper
        );
    }

    AgentDiagnosticsService(
            JdbcAgentRepository agentRepository,
            HttpClient httpClient,
            ObjectMapper objectMapper
    ) {
        this.agentRepository = agentRepository;
        this.httpClient = httpClient;
        this.objectMapper = objectMapper;
    }

    public List<AgentDiagnostic> inspect(String workspaceId) {
        return agentRepository.listConfiguredAgents(workspaceId).stream()
                .map(this::inspectAgent)
                .toList();
    }

    private AgentDiagnostic inspectAgent(ConfiguredAgent agent) {
        var checkedAt = Instant.now().toString();
        var credentialConfigured = agent.credential() != null && !agent.credential().isBlank();
        if (!agent.enabled()) {
            return new AgentDiagnostic(
                    agent.agentKey(),
                    agent.provider(),
                    agent.endpointUrl(),
                    false,
                    credentialConfigured,
                    agent.roleStrategy(),
                    "DISABLED",
                    "Agent is disabled for this workspace",
                    0,
                    checkedAt
            );
        }
        if (agent.provider() == null || agent.provider().isBlank()) {
            return new AgentDiagnostic(
                    agent.agentKey(),
                    "",
                    agent.endpointUrl(),
                    true,
                    credentialConfigured,
                    agent.roleStrategy(),
                    "UNCONFIGURED",
                    "Agent provider is missing",
                    0,
                    checkedAt
            );
        }
        if ("mock-openclaw".equalsIgnoreCase(agent.provider())) {
            return new AgentDiagnostic(
                    agent.agentKey(),
                    agent.provider(),
                    agent.endpointUrl(),
                    true,
                    credentialConfigured,
                    agent.roleStrategy(),
                    "SIMULATED",
                    "Using the built-in mock agent gateway",
                    0,
                    checkedAt
            );
        }
        if (agent.endpointUrl() == null || agent.endpointUrl().isBlank()) {
            return new AgentDiagnostic(
                    agent.agentKey(),
                    agent.provider(),
                    "",
                    true,
                    credentialConfigured,
                    agent.roleStrategy(),
                    "UNCONFIGURED",
                    "Agent endpoint URL is missing",
                    0,
                    checkedAt
            );
        }
        return probeHttpAgent(agent, checkedAt, credentialConfigured);
    }

    private AgentDiagnostic probeHttpAgent(
            ConfiguredAgent agent,
            String checkedAt,
            boolean credentialConfigured
    ) {
        var startedAt = System.nanoTime();
        try {
            var baseUri = normalizeBaseUri(agent.endpointUrl());
            var healthResponse = sendGet(baseUri.resolve("/health"), agent.credential());
            var latencyMillis = Duration.ofNanos(System.nanoTime() - startedAt).toMillis();
            if (healthResponse.statusCode() >= 200 && healthResponse.statusCode() < 300) {
                return new AgentDiagnostic(
                        agent.agentKey(),
                        agent.provider(),
                        agent.endpointUrl(),
                        true,
                        credentialConfigured,
                        agent.roleStrategy(),
                        "HEALTHY",
                        summarizeBody(healthResponse.body()),
                        latencyMillis,
                        checkedAt
                );
            }

            var rootResponse = sendGet(baseUri, agent.credential());
            latencyMillis = Duration.ofNanos(System.nanoTime() - startedAt).toMillis();
            if (rootResponse.statusCode() >= 200 && rootResponse.statusCode() < 300) {
                return new AgentDiagnostic(
                        agent.agentKey(),
                        agent.provider(),
                        agent.endpointUrl(),
                        true,
                        credentialConfigured,
                        agent.roleStrategy(),
                        "REACHABLE",
                        summarizeBody(rootResponse.body()),
                        latencyMillis,
                        checkedAt
                );
            }
            return new AgentDiagnostic(
                    agent.agentKey(),
                    agent.provider(),
                    agent.endpointUrl(),
                    true,
                    credentialConfigured,
                    agent.roleStrategy(),
                    classifyHttpStatus(rootResponse.statusCode()),
                    "HTTP " + rootResponse.statusCode() + bodySuffix(rootResponse.body()),
                    latencyMillis,
                    checkedAt
            );
        } catch (Exception ex) {
            var latencyMillis = Duration.ofNanos(System.nanoTime() - startedAt).toMillis();
            return new AgentDiagnostic(
                    agent.agentKey(),
                    agent.provider(),
                    agent.endpointUrl(),
                    true,
                    credentialConfigured,
                    agent.roleStrategy(),
                    "UNREACHABLE",
                    ex.getMessage() == null ? ex.getClass().getSimpleName() : ex.getMessage(),
                    latencyMillis,
                    checkedAt
            );
        }
    }

    private HttpResponse<String> sendGet(URI uri, String credential) throws Exception {
        var requestBuilder = HttpRequest.newBuilder(uri)
                .timeout(REQUEST_TIMEOUT)
                .header("Accept", "application/json");
        if (credential != null && !credential.isBlank()) {
            requestBuilder.header("Authorization", "Bearer " + credential.trim());
        }
        return httpClient.send(requestBuilder.GET().build(), HttpResponse.BodyHandlers.ofString());
    }

    private URI normalizeBaseUri(String endpointUrl) {
        var normalized = endpointUrl.trim();
        if (normalized.endsWith("/v1/chat/completions")) {
            normalized = normalized.substring(0, normalized.length() - "/v1/chat/completions".length());
        }
        if (!normalized.endsWith("/")) {
            normalized = normalized + "/";
        }
        return URI.create(normalized);
    }

    private String classifyHttpStatus(int statusCode) {
        if (statusCode == 401 || statusCode == 403) {
            return "AUTH_REQUIRED";
        }
        return "DEGRADED";
    }

    private String summarizeBody(String body) {
        if (body == null || body.isBlank()) {
            return "Endpoint responded";
        }
        try {
            JsonNode root = objectMapper.readTree(body);
            if (root.hasNonNull("status")) {
                return root.get("status").asText();
            }
            if (root.hasNonNull("ok")) {
                return "ok=" + root.get("ok").asText();
            }
        } catch (Exception ignored) {
            // fall through to plain text summary
        }
        return truncate(body.replaceAll("\\s+", " ").trim(), 120);
    }

    private String bodySuffix(String body) {
        if (body == null || body.isBlank()) {
            return "";
        }
        return ": " + truncate(body.replaceAll("\\s+", " ").trim(), 120);
    }

    private String truncate(String value, int limit) {
        if (value.length() <= limit) {
            return value;
        }
        return value.substring(0, limit) + "...";
    }
}
