package com.microflow.agent.runtime.infrastructure.provider;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.microflow.agent.domain.model.AgentExecutionTarget;
import com.microflow.agent.runtime.domain.gateway.AgentTurnRequest;
import com.microflow.agent.runtime.domain.gateway.AgentTurnResult;
import com.microflow.agent.runtime.domain.gateway.TurnMessage;
import com.microflow.agent.runtime.domain.model.ToolDescriptor;
import com.microflow.agent.runtime.domain.model.ToolPolicy;
import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

class OpenClawStructuredProtocolRepairTest {
    private final ObjectMapper mapper = new ObjectMapper();
    private final Clock clock = Clock.fixed(Instant.parse("2026-11-24T00:00:00Z"), ZoneOffset.UTC);
    private final List<JsonNode> requests = new CopyOnWriteArrayList<>();
    private final List<String> agentHeaders = new CopyOnWriteArrayList<>();
    private HttpServer server;

    @AfterEach
    void stop() { if (server != null) server.stop(0); }

    @Test
    void aTwoHundredTextCompletionDoesNotProveToolCallCapability() throws Exception {
        var target = serve(200, completion(Map.of("content", "OK")));
        assertThat(gateway().detectCapability("assistant", target).supportsToolCalls()).isFalse();
    }

    @Test
    void capabilityRequiresAnExplicitSideEffectFreeStructuredProbe() throws Exception {
        var target = serve(200, completion(Map.of("tool_calls", List.of(call("capability_probe",
                "{\"marker\":\"microflow-tool-probe\"}")))));
        var capability = gateway().detectCapability("assistant", target);
        assertThat(capability.supportsToolCalls()).isTrue();
        var payload = requests.getFirst();
        assertThat(payload.path("tool_choice").path("function").path("name").asText()).isEqualTo("capability_probe");
        assertThat(payload.path("messages").get(0).path("content").asText()).contains("capability_probe", "microflow-tool-probe");
        assertThat(payload.path("tools").get(0).path("function").path("parameters").path("required").get(0).asText())
                .isEqualTo("marker");
        assertThat(payload.path("tools").get(0).path("function").path("description").asText()).contains("no side effects");
        assertThat(agentHeaders).containsExactly("assistant");
    }

    @ParameterizedTest
    @ValueSource(strings = {"{}", "null", "[]", "", "{broken", "{\"marker\":\"wrong\"}"})
    void emptyMalformedOrIncorrectProbeArgumentsDoNotProveCapability(String arguments) throws Exception {
        var target = serve(200, completion(Map.of("tool_calls", List.of(call("capability_probe", arguments)))));
        assertThat(gateway().detectCapability("assistant", target).supportsToolCalls()).isFalse();
    }

    @Test
    void unrelatedStructuredCallDoesNotProveTheProbeWasFollowed() throws Exception {
        var target = serve(200, completion(Map.of("tool_calls", List.of(call("mail.send", "{}")))));
        assertThat(gateway().detectCapability("assistant", target).supportsToolCalls()).isFalse();
    }

    @ParameterizedTest
    @ValueSource(ints = {400, 422, 500})
    void rejectedProbeDisablesTools(int status) throws Exception {
        var target = serve(status, "{\"error\":\"fixture rejection\"}");
        assertThat(gateway().detectCapability("assistant", target).supportsToolCalls()).isFalse();
    }

    @ParameterizedTest
    @ValueSource(strings = {"{broken", "null", "[]", "17", "", "{} trailing"})
    void malformedStringArgumentsFailTheWholeTurnInsteadOfUsingDefaultTargets(String arguments) throws Exception {
        var target = serve(200, completion(Map.of("content", "Proceed with the default task",
                "tool_calls", List.of(call("task.update_status", arguments)))));
        var result = gateway().turn(request(), target);
        assertThat(result.kind()).isEqualTo(AgentTurnResult.Kind.FAILED);
        assertThat(result.toolCalls()).isEmpty();
    }

    @ParameterizedTest
    @ValueSource(strings = {"null", "[]", "17"})
    void nonObjectWireArgumentsFailTheWholeTurn(String rawNode) throws Exception {
        var target = serve(200, completion(Map.of("tool_calls", List.of(call("task.update_status", mapper.readTree(rawNode))))));
        assertThat(gateway().turn(request(), target).kind()).isEqualTo(AgentTurnResult.Kind.FAILED);
    }

    @Test
    void missingArgumentsCannotBecomeAnEmptyObject() throws Exception {
        var target = serve(200, completion(Map.of("tool_calls", List.of(Map.of("id", "call_1", "type", "function",
                "function", Map.of("name", "task.update_status"))))));
        assertThat(gateway().turn(request(), target).kind()).isEqualTo(AgentTurnResult.Kind.FAILED);
    }

    @Test
    void malformedCallShapeCannotSilentlyBecomeAPlainTextCompletion() throws Exception {
        var target = serve(200, completion(Map.of("content", "Proceed", "tool_calls", List.of(
                Map.of("id", "call_1", "type", "function", "function", Map.of("arguments", "{}"))))));
        assertThat(gateway().turn(request(), target).kind()).isEqualTo(AgentTurnResult.Kind.FAILED);
    }

    @Test
    void nonArrayToolCallsCannotSilentlyBecomeAPlainTextCompletion() throws Exception {
        var target = serve(200, completion(Map.of("content", "Proceed", "tool_calls", Map.of("name", "task.read"))));
        assertThat(gateway().turn(request(), target).kind()).isEqualTo(AgentTurnResult.Kind.FAILED);
    }

    @Test
    void malformedLegacyFunctionArgumentsAreRejected() throws Exception {
        var target = serve(200, completion(Map.of("function_call", Map.of("name", "task.update_status", "arguments", "{broken"))));
        assertThat(gateway().turn(request(), target).kind()).isEqualTo(AgentTurnResult.Kind.FAILED);
    }

    @Test
    void legacyCallsReceiveDistinctIdsAcrossTurns() throws Exception {
        var target = serve(200, completion(Map.of("function_call", Map.of("name", "task.read", "arguments", "{}"))));
        var adapter = gateway();
        var first = adapter.turn(request(), target);
        var second = adapter.turn(request(), target);
        assertThat(first.kind()).isEqualTo(AgentTurnResult.Kind.TOOL_CALLS);
        assertThat(second.kind()).isEqualTo(AgentTurnResult.Kind.TOOL_CALLS);
        assertThat(first.toolCalls().getFirst().callId()).isNotBlank()
                .isNotEqualTo(second.toolCalls().getFirst().callId());
    }

    @ParameterizedTest
    @ValueSource(strings = {"null", "\"\"", "\"  \"", "13"})
    void modernCallsRequireANonblankStringId(String idNode) throws Exception {
        var wireCall = new java.util.LinkedHashMap<>(call("task.read", "{}"));
        wireCall.put("id", mapper.readTree(idNode));
        var target = serve(200, completion(Map.of("tool_calls", List.of(wireCall))));
        assertThat(gateway().turn(request(), target).kind()).isEqualTo(AgentTurnResult.Kind.FAILED);
    }

    @Test
    void modernCallsCannotInventAnIdWhenItIsMissing() throws Exception {
        var wireCall = new java.util.LinkedHashMap<>(call("task.read", "{}"));
        wireCall.remove("id");
        var target = serve(200, completion(Map.of("tool_calls", List.of(wireCall))));
        assertThat(gateway().turn(request(), target).kind()).isEqualTo(AgentTurnResult.Kind.FAILED);
    }

    @Test
    void duplicateIdsRejectTheWholeModernBatch() throws Exception {
        var target = serve(200, completion(Map.of("tool_calls", List.of(
                call("task.read", "{}"), call("task.update_status", "{\"status\":\"DONE\"}")))));
        var result = gateway().turn(request(), target);
        assertThat(result.kind()).isEqualTo(AgentTurnResult.Kind.FAILED);
        assertThat(result.toolCalls()).isEmpty();
    }

    @Test
    void aMalformedCallCannotExecuteEvenWhenAnotherCallInTheSameBatchIsValid() throws Exception {
        var target = serve(200, completion(Map.of("tool_calls", List.of(call("task.read", "{}"), call("task.update_status", "{broken")))));
        var result = gateway().turn(request(), target);
        assertThat(result.kind()).isEqualTo(AgentTurnResult.Kind.FAILED);
        assertThat(result.toolCalls()).isEmpty();
    }

    @Test
    void objectArgumentsAndOrdinaryTextKeepTheirDistinctBehaviors() throws Exception {
        var target = serve(200, completion(Map.of("tool_calls", List.of(call("task.update_status", Map.of("status", "DONE"))))));
        var result = gateway().turn(request(), target);
        assertThat(result.kind()).isEqualTo(AgentTurnResult.Kind.TOOL_CALLS);
        assertThat(result.toolCalls().getFirst().input()).containsEntry("status", "DONE");
        var payload = requests.getFirst();
        assertThat(payload.path("tools").get(0).path("function").path("name").asText()).isEqualTo("task.update_status");
        assertThat(payload.path("messages").get(0).path("content").asText()).contains("fixture context");
    }

    @Test
    void proseDescribingAnActionIsStillOnlyText() throws Exception {
        var target = serve(200, completion(Map.of("content", "Call task.update_status with status DONE.")));
        var result = gateway().turn(request(), target);
        assertThat(result.kind()).isEqualTo(AgentTurnResult.Kind.TEXT);
        assertThat(result.toolCalls()).isEmpty();
    }

    private OpenClawTurnGateway gateway() { return new OpenClawTurnGateway(mapper, clock); }

    private AgentTurnRequest request() {
        return new AgentTurnRequest("run_fixture", "ws_fixture", null, "assistant", "fixture goal", "fixture context",
                List.of(TurnMessage.user("fixture goal")), List.of(new ToolDescriptor("task.update_status", "Status", "Update",
                Map.of("type", "object"), ToolPolicy.Permission.APPROVAL, ToolPolicy.Risk.INTERNAL_WRITE, true, null)), true);
    }

    private Map<String, Object> call(String name, Object arguments) {
        return Map.of("id", "call_1", "type", "function", "function", Map.of("name", name, "arguments", arguments));
    }

    private String completion(Map<String, Object> message) throws Exception {
        return mapper.writeValueAsString(Map.of("choices", List.of(Map.of("message", message))));
    }

    private AgentExecutionTarget serve(int status, String body) throws Exception {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v1/chat/completions", exchange -> {
            requests.add(mapper.readTree(exchange.getRequestBody().readAllBytes()));
            agentHeaders.add(exchange.getRequestHeaders().getFirst("x-openclaw-agent-id"));
            var bytes = body.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(status, bytes.length);
            exchange.getResponseBody().write(bytes);
            exchange.close();
        });
        server.start();
        return new AgentExecutionTarget("OPENCLAW", "http://127.0.0.1:" + server.getAddress().getPort(), null);
    }
}
