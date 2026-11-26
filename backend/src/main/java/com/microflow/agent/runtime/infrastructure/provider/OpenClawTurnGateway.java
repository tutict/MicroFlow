package com.microflow.agent.runtime.infrastructure.provider;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.ObjectMapper;
import com.microflow.agent.domain.model.AgentExecutionTarget;
import com.microflow.agent.runtime.domain.gateway.AgentTurnRequest;
import com.microflow.agent.runtime.domain.gateway.AgentTurnResult;
import com.microflow.agent.runtime.domain.gateway.ProviderCapability;
import com.microflow.agent.runtime.domain.gateway.TurnMessage;
import com.microflow.agent.runtime.domain.model.ToolCallRequest;
import com.microflow.agent.runtime.domain.model.ToolDescriptor;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * OpenClaw adapter for the structured turn protocol.
 *
 * <p>The legacy gateway only read {@code choices[0].message.content}. This one
 * also reads {@code tool_calls} and, critically, never fabricates a call out of
 * prose: if the provider answers with text, the run ends with text.
 */
@Component
public class OpenClawTurnGateway {

    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(90);
    private static final Duration PROBE_TIMEOUT = Duration.ofSeconds(20);
    private static final String PROBE_MARKER = "microflow-tool-probe";

    private final HttpClient httpClient;
    private final ObjectMapper objectMapper;
    private final Clock clock;

    @Autowired
    public OpenClawTurnGateway(ObjectMapper objectMapper, Clock clock) {
        this(HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build(), objectMapper, clock);
    }

    OpenClawTurnGateway(HttpClient httpClient, ObjectMapper objectMapper, Clock clock) {
        this.httpClient = httpClient;
        this.objectMapper = objectMapper;
        this.clock = clock;
    }

    public AgentTurnResult turn(AgentTurnRequest request, AgentExecutionTarget target) {
        try {
            var payload = buildPayload(request);
            var response = invoke(target, payload, request.agentKey());
            if (response.statusCode() == 400 || response.statusCode() == 404) {
                response = invoke(target, payload, "main");
            }
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                return AgentTurnResult.failed(
                        "OpenClaw gateway returned HTTP " + response.statusCode() + errorSuffix(response.body()));
            }
            return parseTurn(response.body());
        } catch (Exception exception) {
            var message = exception.getMessage() == null
                    ? exception.getClass().getSimpleName()
                    : exception.getMessage();
            return AgentTurnResult.failed(message);
        }
    }

    /**
     * Requests a named function with no side effects and verifies the actual
     * structured response. Accepting a schema without calling the probe is not
     * evidence that this agent can use tools.
     */
    public ProviderCapability detectCapability(String agentKey, AgentExecutionTarget target) {
        try {
            var payload = new LinkedHashMap<String, Object>();
            payload.put("model", "openclaw");
            payload.put("user", "microflow:capability-probe");
            payload.put("stream", false);
            payload.put("max_tokens", 128);
            payload.put("tool_choice", Map.of("type", "function", "function", Map.of("name", "capability_probe")));
            payload.put("messages", List.of(Map.of("role", "user", "content",
                    "Call capability_probe once with marker " + PROBE_MARKER + ". This probe has no side effects.")));
            payload.put("tools", List.of(Map.of(
                    "type", "function",
                    "function", Map.of(
                            "name", "capability_probe",
                            "description", "A capability check with no side effects.",
                            "parameters", Map.of("type", "object", "properties", Map.of(
                                    "marker", Map.of("type", "string", "enum", List.of(PROBE_MARKER))),
                                    "required", List.of("marker"), "additionalProperties", false)
                    )
            )));
            var response = invokeWithTimeout(target, payload, agentKey, PROBE_TIMEOUT);
            var now = Instant.now(clock).toString();
            if (response.statusCode() >= 200 && response.statusCode() < 300) {
                var turn = parseTurn(response.body());
                if (turn.kind() == AgentTurnResult.Kind.TOOL_CALLS && turn.toolCalls().size() == 1) {
                    var call = turn.toolCalls().getFirst();
                    if ("capability_probe".equals(call.toolKey())
                            && call.input().size() == 1 && PROBE_MARKER.equals(call.input().get("marker"))) {
                        return new ProviderCapability(true, "provider returned the structured capability probe", now);
                    }
                }
                return ProviderCapability.unsupported("provider did not return the requested structured capability probe", now);
            }
            if (response.statusCode() == 400 || response.statusCode() == 422) {
                return ProviderCapability.unsupported(
                        "provider rejected the tools declaration (HTTP " + response.statusCode() + ")",
                        now);
            }
            return ProviderCapability.unsupported(
                    "capability probe returned HTTP " + response.statusCode(), now);
        } catch (Exception exception) {
            var detail = exception.getMessage() == null
                    ? exception.getClass().getSimpleName()
                    : exception.getMessage();
            return ProviderCapability.unsupported("capability probe failed: " + detail,
                    Instant.now(clock).toString());
        }
    }

    private Map<String, Object> buildPayload(AgentTurnRequest request) {
        var payload = new LinkedHashMap<String, Object>();
        payload.put("model", "openclaw");
        payload.put("user", "microflow:%s:%s".formatted(request.workspaceId(), request.sessionId()));
        payload.put("stream", false);
        var messages = new ArrayList<Map<String, Object>>();
        messages.add(Map.of("role", "system", "content", systemPrompt(request)));
        for (var message : request.messages()) {
            messages.add(toWireMessage(message));
        }
        payload.put("messages", messages);
        if (request.toolsEnabled() && !request.tools().isEmpty()) {
            payload.put("tools", request.tools().stream().map(this::toWireTool).toList());
            payload.put("tool_choice", "auto");
        }
        return payload;
    }

    private Map<String, Object> toWireMessage(TurnMessage message) {
        var wire = new LinkedHashMap<String, Object>();
        wire.put("role", message.role());
        wire.put("content", message.content() == null ? "" : message.content());
        if (message.toolCalls() != null && !message.toolCalls().isEmpty()) {
            wire.put("tool_calls", message.toolCalls().stream().map(call -> Map.of(
                    "id", call.callId(),
                    "type", "function",
                    "function", Map.of(
                            "name", call.toolKey(),
                            "arguments", writeJson(call.inputOrEmpty())
                    )
            )).toList());
        }
        if (message.toolCallId() != null) {
            wire.put("tool_call_id", message.toolCallId());
        }
        return wire;
    }

    private Map<String, Object> toWireTool(ToolDescriptor descriptor) {
        return Map.of(
                "type", "function",
                "function", Map.of(
                        "name", descriptor.key(),
                        "description", descriptor.description(),
                        "parameters", descriptor.inputSchema()
                )
        );
    }

    private String systemPrompt(AgentTurnRequest request) {
        var prompt = new StringBuilder();
        prompt.append("You are MicroFlow agent @").append(request.agentKey()).append(".\n");
        prompt.append("Goal:\n").append(request.goal()).append("\n\n");
        if (request.contextBlock() != null && !request.contextBlock().isBlank()) {
            prompt.append("Workspace context:\n").append(request.contextBlock()).append("\n\n");
        }
        prompt.append("Rules:\n");
        prompt.append("- You may call the provided tools. A tool call is the only way to perform an action; never describe an action and assume it ran.\n");
        prompt.append("- Write operations pause the run for human approval; the user sees the action, target and impact before it executes.\n");
        prompt.append("- If no tool is needed, reply with the final answer and do not call a tool.\n");
        prompt.append("- Cite workspace knowledge inline as [kb:documentId] when you rely on it.");
        return prompt.toString();
    }

    private AgentTurnResult parseTurn(String body) throws Exception {
        var root = objectMapper.readTree(body);
        var message = root.path("choices").path(0).path("message");
        if (message.isMissingNode()) {
            return AgentTurnResult.failed("OpenClaw gateway returned no message");
        }
        var calls = readToolCalls(message.path("tool_calls"));
        if (calls.isEmpty()) {
            calls = readLegacyFunctionCall(message.path("function_call"));
        }
        var text = readContent(message.path("content"));
        if (!calls.isEmpty()) {
            return AgentTurnResult.toolCalls(calls, text);
        }
        if (text == null || text.isBlank()) {
            return AgentTurnResult.failed("OpenClaw gateway returned an empty completion");
        }
        return AgentTurnResult.text(text.trim());
    }

    private List<ToolCallRequest> readToolCalls(JsonNode node) {
        if (node.isMissingNode() || node.isNull()) {
            return List.of();
        }
        if (!node.isArray()) {
            throw new IllegalArgumentException("Provider tool_calls must be an array");
        }
        var calls = new ArrayList<ToolCallRequest>();
        var ids = new HashSet<String>();
        for (var item : node) {
            var function = item.path("function");
            var name = function.path("name").asString(null);
            if (name == null || name.isBlank()) {
                throw new IllegalArgumentException("Provider tool call requires a function name");
            }
            var id = item.path("id");
            if (!id.isTextual() || id.asString().isBlank()) {
                throw new IllegalArgumentException("Provider tool call requires a nonblank string call ID");
            }
            var callId = id.asString();
            if (!ids.add(callId)) {
                throw new IllegalArgumentException("Provider returned duplicate tool call IDs");
            }
            calls.add(new ToolCallRequest(callId, name, parseArguments(function.path("arguments"))));
        }
        return calls;
    }

    private List<ToolCallRequest> readLegacyFunctionCall(JsonNode node) {
        if (node.isMissingNode() || node.isNull()) {
            return List.of();
        }
        var name = node.path("name").asString(null);
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("Provider function call requires a function name");
        }
        // Legacy function_call carries no ID. Assign once before the runtime
        // persists the assistant message; approval recovery reuses that record.
        return List.of(new ToolCallRequest("call_legacy_" + UUID.randomUUID(), name,
                parseArguments(node.path("arguments"))));
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> parseArguments(JsonNode node) {
        if (node.isObject()) {
            return objectMapper.convertValue(node, LinkedHashMap.class);
        }
        if (!node.isTextual() || node.asString().isBlank()) {
            throw new IllegalArgumentException("Provider tool arguments must be a JSON object");
        }
        try {
            JsonNode parsed = objectMapper.reader().with(DeserializationFeature.FAIL_ON_TRAILING_TOKENS)
                    .readTree(node.asString());
            if (parsed == null || !parsed.isObject()) {
                throw new IllegalArgumentException("Provider tool arguments must be a JSON object");
            }
            return objectMapper.convertValue(parsed, LinkedHashMap.class);
        } catch (Exception exception) {
            throw new IllegalArgumentException("Provider tool arguments must be a JSON object", exception);
        }
    }

    private String readContent(JsonNode content) {
        if (content.isMissingNode() || content.isNull()) {
            return null;
        }
        if (content.isTextual()) {
            return content.asString();
        }
        if (content.isArray()) {
            var text = new StringBuilder();
            for (var item : content) {
                if ("text".equals(item.path("type").asString())) {
                    text.append(item.path("text").asString(""));
                }
            }
            return text.toString();
        }
        return content.toString();
    }

    private HttpResponse<String> invoke(
            AgentExecutionTarget target,
            Map<String, Object> payload,
            String agentId
    ) throws Exception {
        return invokeWithTimeout(target, payload, agentId, REQUEST_TIMEOUT);
    }

    private HttpResponse<String> invokeWithTimeout(
            AgentExecutionTarget target,
            Map<String, Object> payload,
            String agentId,
            Duration timeout
    ) throws Exception {
        var builder = HttpRequest.newBuilder(resolveUri(target.endpointUrl()))
                .timeout(timeout)
                .header("Content-Type", "application/json")
                .header("Accept", "application/json")
                .header("x-openclaw-message-channel", "microflow");
        if (agentId != null && !agentId.isBlank()) {
            builder.header("x-openclaw-agent-id", agentId);
        }
        if (target.credential() != null && !target.credential().isBlank()) {
            builder.header("Authorization", "Bearer " + target.credential().trim());
        }
        return httpClient.send(
                builder.POST(HttpRequest.BodyPublishers.ofString(writeJson(payload))).build(),
                HttpResponse.BodyHandlers.ofString());
    }

    private URI resolveUri(String endpointUrl) {
        var normalized = endpointUrl == null ? "" : endpointUrl.trim();
        if (normalized.isBlank()) {
            throw new IllegalArgumentException("Agent endpoint URL is required");
        }
        if (normalized.endsWith("/v1/chat/completions")) {
            return URI.create(normalized);
        }
        return URI.create(normalized.endsWith("/")
                ? normalized + "v1/chat/completions"
                : normalized + "/v1/chat/completions");
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to serialize provider request", exception);
        }
    }

    private String errorSuffix(String body) {
        if (body == null || body.isBlank()) {
            return "";
        }
        var trimmed = body.trim();
        return ": " + trimmed.substring(0, Math.min(trimmed.length(), 400));
    }

    @SuppressWarnings("unused")
    private String normalize(String value) {
        return value == null ? "" : value.toLowerCase(Locale.ROOT);
    }
}
