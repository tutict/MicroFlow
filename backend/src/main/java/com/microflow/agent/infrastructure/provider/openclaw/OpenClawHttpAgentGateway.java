package com.microflow.agent.infrastructure.provider.openclaw;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.microflow.agent.domain.model.AgentExecutionRequest;
import com.microflow.agent.domain.model.AgentExecutionResult;
import com.microflow.agent.domain.model.AgentExecutionTarget;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class OpenClawHttpAgentGateway {

    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(90);

    private final HttpClient httpClient;
    private final ObjectMapper objectMapper;

    @Autowired
    public OpenClawHttpAgentGateway(ObjectMapper objectMapper) {
        this(HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build(), objectMapper);
    }

    OpenClawHttpAgentGateway(HttpClient httpClient, ObjectMapper objectMapper) {
        this.httpClient = httpClient;
        this.objectMapper = objectMapper;
    }

    public AgentExecutionResult execute(AgentExecutionRequest request, AgentExecutionTarget target) {
        try {
            var response = invoke(request, target, request.agentKey());
            if (response.statusCode() == 400 || response.statusCode() == 404) {
                response = invoke(request, target, "main");
            }
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                return new AgentExecutionResult(
                        false,
                        null,
                        "OpenClaw gateway returned HTTP " + response.statusCode() + errorSuffix(response.body())
                );
            }
            var output = extractOutput(response.body());
            if (output == null || output.isBlank()) {
                return new AgentExecutionResult(false, null, "OpenClaw gateway returned an empty completion");
            }
            return new AgentExecutionResult(true, output.trim(), null);
        } catch (Exception ex) {
            return new AgentExecutionResult(false, null, ex.getMessage() == null ? ex.getClass().getSimpleName() : ex.getMessage());
        }
    }

    private HttpResponse<String> invoke(
            AgentExecutionRequest request,
            AgentExecutionTarget target,
            String openClawAgentId
    ) throws IOException, InterruptedException {
        var payload = Map.of(
                "model", "openclaw",
                "user", sessionKey(request),
                "stream", false,
                "messages", new Object[] {
                        Map.of("role", "user", "content", request.prompt())
                }
        );
        var requestBuilder = HttpRequest.newBuilder(resolveChatCompletionUri(target.endpointUrl()))
                .timeout(REQUEST_TIMEOUT)
                .header("Content-Type", "application/json")
                .header("Accept", "application/json")
                .header("x-openclaw-session-key", sessionKey(request))
                .header("x-openclaw-message-channel", "microflow");
        if (openClawAgentId != null && !openClawAgentId.isBlank()) {
            requestBuilder.header("x-openclaw-agent-id", openClawAgentId);
        }
        if (target.credential() != null && !target.credential().isBlank()) {
            requestBuilder.header("Authorization", "Bearer " + target.credential().trim());
        }
        var httpRequest = requestBuilder
                .POST(HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(payload)))
                .build();
        return httpClient.send(httpRequest, HttpResponse.BodyHandlers.ofString());
    }

    private URI resolveChatCompletionUri(String endpointUrl) {
        var normalized = endpointUrl == null ? "" : endpointUrl.trim();
        if (normalized.isBlank()) {
            throw new IllegalArgumentException("Agent endpoint URL is required");
        }
        if (normalized.endsWith("/v1/chat/completions")) {
            return URI.create(normalized);
        }
        if (normalized.endsWith("/")) {
            return URI.create(normalized + "v1/chat/completions");
        }
        return URI.create(normalized + "/v1/chat/completions");
    }

    private String sessionKey(AgentExecutionRequest request) {
        return "microflow:%s:%s:%s".formatted(request.workspaceId(), request.channelId(), request.agentKey());
    }

    private String extractOutput(String body) throws IOException {
        var root = objectMapper.readTree(body);
        var content = root.path("choices").path(0).path("message").path("content");
        if (content.isMissingNode() || content.isNull()) {
            return null;
        }
        if (content.isTextual()) {
            return content.asText();
        }
        if (content.isArray()) {
            var text = new StringBuilder();
            for (JsonNode item : content) {
                if (item.path("type").asText("").equals("text")) {
                    text.append(item.path("text").asText(""));
                }
            }
            return text.toString();
        }
        return content.toString();
    }

    private String errorSuffix(String body) {
        if (body == null || body.isBlank()) {
            return "";
        }
        return ": " + body.trim();
    }
}
