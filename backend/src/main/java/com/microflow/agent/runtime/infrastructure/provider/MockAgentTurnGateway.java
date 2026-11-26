package com.microflow.agent.runtime.infrastructure.provider;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import com.microflow.agent.runtime.domain.gateway.AgentTurnRequest;
import com.microflow.agent.runtime.domain.gateway.AgentTurnResult;
import com.microflow.agent.runtime.domain.gateway.ProviderCapability;
import com.microflow.agent.runtime.domain.model.ToolCallRequest;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Deterministic provider used by tests and by the fallback catalog entry.
 *
 * <p>It can emit structured tool calls from a scripted plan so the approval path
 * is exercised without a real model. The plan is configuration, not prompt text:
 * the runtime still receives {@code tool_calls}, never prose it has to guess at.
 */
@Component
public class MockAgentTurnGateway {

    private final ObjectMapper objectMapper;
    private final Clock clock;
    private final JsonNode plan;

    private final Map<String, AtomicInteger> turnCounters = new ConcurrentHashMap<>();

    public MockAgentTurnGateway(
            ObjectMapper objectMapper,
            Clock clock,
            @Value("${microflow.agent.mock-plan:}") String planJson
    ) {
        this.objectMapper = objectMapper;
        this.clock = clock;
        this.plan = parsePlan(planJson);
    }

    public AgentTurnResult turn(AgentTurnRequest request) {
        var turns = plan.path("turns");
        if (!turns.isArray() || turns.isEmpty()) {
            return AgentTurnResult.text(defaultText(request));
        }
        var index = turnCounters
                .computeIfAbsent(request.sessionId(), key -> new AtomicInteger(0))
                .getAndIncrement();
        if (index >= turns.size()) {
            return AgentTurnResult.text(defaultText(request));
        }
        var scripted = turns.get(index);
        var text = scripted.path("text").asString(null);
        var calls = readCalls(scripted.path("toolCalls"));
        if (!calls.isEmpty()) {
            return AgentTurnResult.toolCalls(calls, text);
        }
        return AgentTurnResult.text(text == null || text.isBlank() ? defaultText(request) : text);
    }

    public ProviderCapability detectCapability(String workspaceId, String agentKey) {
        return new ProviderCapability(true, "mock provider supports structured tool calls",
                Instant.now(clock).toString());
    }

    private String defaultText(AgentTurnRequest request) {
        return ("[%s] Run completed for goal: %s")
                .formatted(request.agentKey(), summarize(request.goal()));
    }

    private String summarize(String value) {
        if (value == null || value.isBlank()) {
            return "(no goal)";
        }
        var normalized = value.replaceAll("\\s+", " ").trim();
        return normalized.length() <= 120 ? normalized : normalized.substring(0, 120) + "...";
    }

    private List<ToolCallRequest> readCalls(JsonNode node) {
        if (!node.isArray()) {
            return List.of();
        }
        var calls = new ArrayList<ToolCallRequest>();
        for (var item : node) {
            var toolKey = item.path("toolKey").asString(null);
            if (toolKey == null || toolKey.isBlank()) {
                continue;
            }
            var callId = item.path("callId").asString("call_mock_" + UUID.randomUUID());
            calls.add(new ToolCallRequest(callId, toolKey, readInput(item.path("input"))));
        }
        return calls;
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> readInput(JsonNode node) {
        if (node.isMissingNode() || node.isNull()) {
            return Map.of();
        }
        try {
            return objectMapper.convertValue(node, LinkedHashMap.class);
        } catch (RuntimeException exception) {
            return Map.of();
        }
    }

    private JsonNode parsePlan(String planJson) {
        if (planJson == null || planJson.isBlank()) {
            return objectMapper.createObjectNode();
        }
        try {
            return objectMapper.readTree(planJson);
        } catch (Exception exception) {
            throw new IllegalStateException("microflow.agent.mock-plan is not valid JSON", exception);
        }
    }
}
