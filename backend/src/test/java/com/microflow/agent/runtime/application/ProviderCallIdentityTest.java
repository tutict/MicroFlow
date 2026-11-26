package com.microflow.agent.runtime.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import tools.jackson.databind.ObjectMapper;
import com.microflow.agent.domain.model.AgentExecutionTarget;
import com.microflow.agent.runtime.domain.gateway.AgentTurnGateway;
import com.microflow.agent.runtime.domain.gateway.AgentTurnRequest;
import com.microflow.agent.runtime.domain.gateway.AgentTurnResult;
import com.microflow.agent.runtime.domain.gateway.ProviderCapability;
import com.microflow.agent.runtime.domain.model.AgentRunSession;
import com.microflow.agent.runtime.domain.model.AgentRunStatus;
import com.microflow.agent.runtime.domain.model.AgentToolInvocation;
import com.microflow.agent.runtime.domain.model.ToolCallRequest;
import com.microflow.agent.runtime.domain.model.ToolDescriptor;
import com.microflow.agent.runtime.domain.model.ToolPolicy;
import com.microflow.agent.runtime.domain.tool.AgentTool;
import com.microflow.agent.runtime.domain.tool.ToolContext;
import com.microflow.agent.runtime.domain.tool.ToolResult;
import com.microflow.agent.runtime.infrastructure.persistence.JdbcAgentRuntimeRepository;
import com.microflow.agent.runtime.infrastructure.persistence.JdbcConnectorRepository;
import com.microflow.agent.runtime.infrastructure.provider.OpenClawTurnGateway;
import com.microflow.agent.runtime.infrastructure.provider.MockAgentTurnGateway;
import com.microflow.agent.runtime.infrastructure.tool.ToolRegistry;
import com.microflow.bootstrap.schema.SchemaMaintenanceInitializer;
import com.microflow.common.jdbc.JdbcTemplate;
import com.microflow.realtime.broadcaster.RealtimeBroadcaster;
import com.microflow.workspace.application.service.WorkspaceAccessGuard;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.AbstractExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

class ProviderCallIdentityTest {
    @TempDir Path directory;
    private final ObjectMapper mapper = new ObjectMapper();
    private final Clock clock = Clock.fixed(Instant.parse("2026-11-24T00:00:00Z"), ZoneOffset.UTC);
    private final AtomicInteger reads = new AtomicInteger();
    private final AtomicInteger drafts = new AtomicInteger();
    private final AtomicInteger writes = new AtomicInteger();
    private final HoldingExecutor executor = new HoldingExecutor();
    private final ToolRegistry tools = mock(ToolRegistry.class);
    private final AgentContextBuilder contexts = mock(AgentContextBuilder.class);
    private final JdbcConnectorRepository connectors = mock(JdbcConnectorRepository.class);
    private JdbcAgentRuntimeRepository repository;
    private AgentTurnGateway gateway;
    private HttpServer server;

    @BeforeEach
    void initialize() {
        var jdbc = new JdbcTemplate(new DriverManagerDataSource("jdbc:sqlite:" + directory.resolve("runtime.db")));
        new SchemaMaintenanceInitializer(jdbc).initializeSchema();
        repository = new JdbcAgentRuntimeRepository(jdbc, clock, mapper);
        when(contexts.build(any())).thenReturn(new AgentContextBuilder.RunContext("context", List.of(), "context"));
        when(connectors.listByWorkspace("ws_fixture")).thenReturn(List.of());
        var read = new CountingTool("task.read", reads, false);
        var draft = new CountingTool("artifact.create", drafts, false);
        var write = new CountingTool("task.update_status", writes, true);
        when(tools.descriptorsFor(any())).thenReturn(List.of(read.descriptor(), draft.descriptor(), write.descriptor()));
        when(tools.require("task.read")).thenReturn(read);
        when(tools.require("artifact.create")).thenReturn(draft);
        when(tools.require("task.update_status")).thenReturn(write);
        repository.insertSession(new AgentRunSession("run_fixture", "ws_fixture", null, null, null, "usr_fixture", "assistant",
                "TASK", AgentRunStatus.QUEUED, "fixture", null, null, "NONE", null, 0, 0, 0,
                clock.instant().toString(), null, null, clock.instant().toString()));
    }

    @AfterEach
    void stop() { if (server != null) server.stop(0); }

    @Test
    void successiveLegacyActionsPersistDistinctIdsAndResumeAfterRestartWithoutReplay() throws Exception {
        serve(List.of(legacy("task.read"), legacy("artifact.create"), legacy("task.update_status"),
                Map.of("content", "Finished")));
        runtime().executeRun("run_fixture");
        assertThat(reads).hasValue(1);
        assertThat(drafts).hasValue(1);
        assertThat(writes).hasValue(0);
        assertThat(repository.findSession("run_fixture").orElseThrow().status()).isEqualTo(AgentRunStatus.WAITING_APPROVAL);
        var calls = repository.listInvocations("run_fixture");
        assertThat(calls).hasSize(3);
        assertThat(calls).extracting(AgentToolInvocation::idempotencyKey).doesNotHaveDuplicates();
        var approval = repository.findPendingApproval("run_fixture").orElseThrow();
        var restored = runtime();
        restored.recoverAfterRestart();
        assertThat(repository.findPendingApproval("run_fixture")).hasValue(approval);
        restored.decideApproval("usr_fixture", "run_fixture", approval.id(), "APPROVE", "Reviewed");
        executor.runNext();
        assertThat(reads).hasValue(1);
        assertThat(drafts).hasValue(1);
        assertThat(writes).hasValue(1);
        assertThat(repository.findSession("run_fixture").orElseThrow().status()).isEqualTo(AgentRunStatus.SUCCEEDED);
        assertThat(repository.listInvocations("run_fixture")).hasSize(3).allSatisfy(call ->
                assertThat(call.status()).isEqualTo(AgentToolInvocation.Status.SUCCEEDED));
        assertThat(repository.listMessages("run_fixture").stream().filter(message -> "tool".equals(message.role())))
                .hasSize(3);
    }

    @Test
    void aModernIdReusedForAnotherTurnFailsBeforeMisusingTheFirstResult() throws Exception {
        serve(List.of(modern("task.read"), modern("task.update_status"), Map.of("content", "Finished")));
        runtime().executeRun("run_fixture");
        assertThat(reads).hasValue(1);
        assertThat(writes).hasValue(0);
        assertThat(repository.listApprovals("run_fixture", null)).isEmpty();
        assertThat(repository.listInvocations("run_fixture")).hasSize(1);
        var run = repository.findSession("run_fixture").orElseThrow();
        assertThat(run.status()).isEqualTo(AgentRunStatus.FAILED);
        assertThat(run.errorMessage()).containsIgnoringCase("call ID");
    }

    @Test
    void omittedScriptIdsRemainDistinctAcrossTurnsAndApprovalContinuation() throws Exception {
        scripted(List.of(
                Map.of("toolCalls", List.of(Map.of("toolKey", "task.read", "input", Map.of()))),
                Map.of("toolCalls", List.of(Map.of("toolKey", "artifact.create", "input", Map.of()))),
                Map.of("toolCalls", List.of(Map.of("toolKey", "task.update_status", "input", Map.of()))),
                Map.of("text", "Finished")));
        var service = runtime();
        service.executeRun("run_fixture");
        assertThat(reads).hasValue(1);
        assertThat(drafts).hasValue(1);
        assertThat(writes).hasValue(0);
        assertThat(repository.findSession("run_fixture").orElseThrow().status()).isEqualTo(AgentRunStatus.WAITING_APPROVAL);
        assertThat(repository.listInvocations("run_fixture")).hasSize(3)
                .extracting(AgentToolInvocation::idempotencyKey).doesNotHaveDuplicates();
        var approval = repository.findPendingApproval("run_fixture").orElseThrow();
        service.decideApproval("usr_fixture", "run_fixture", approval.id(), "APPROVE", null);
        executor.runNext();
        assertThat(reads).hasValue(1);
        assertThat(drafts).hasValue(1);
        assertThat(writes).hasValue(1);
        assertThat(repository.findSession("run_fixture").orElseThrow().status()).isEqualTo(AgentRunStatus.SUCCEEDED);
    }

    @Test
    void duplicateScriptIdsRejectTheBatchBeforeAnyToolExecutes() throws Exception {
        scripted(List.of(Map.of("toolCalls", List.of(
                Map.of("callId", "duplicate", "toolKey", "task.read", "input", Map.of()),
                Map.of("callId", "duplicate", "toolKey", "task.update_status", "input", Map.of())))));
        runtime().executeRun("run_fixture");
        assertThat(reads).hasValue(0);
        assertThat(writes).hasValue(0);
        assertThat(repository.listInvocations("run_fixture")).isEmpty();
        assertThat(repository.listApprovals("run_fixture", null)).isEmpty();
        assertThat(repository.findSession("run_fixture").orElseThrow().status()).isEqualTo(AgentRunStatus.FAILED);
    }

    @ParameterizedTest
    @ValueSource(strings = {"TOOL", "INPUT"})
    void anExplicitRetryCannotAssociateAChangedActionWithAnOlderInvocation(String change) {
        gateway = mock(AgentTurnGateway.class);
        when(gateway.detectCapability("ws_fixture", "assistant"))
                .thenReturn(new ProviderCapability(true, "fixture", clock.instant().toString()));
        var changedCall = new ToolCallRequest("same_id", "TOOL".equals(change) ? "task.update_status" : "task.read",
                "INPUT".equals(change) ? Map.of("target", "new") : Map.of("target", "old"));
        when(gateway.turn(any())).thenReturn(
                AgentTurnResult.toolCalls(List.of(new ToolCallRequest("same_id", "task.read", Map.of("target", "old"))), "Read"),
                AgentTurnResult.failed("Provider disconnected"),
                AgentTurnResult.toolCalls(List.of(changedCall), "Changed action"), AgentTurnResult.text("Finished"));
        var service = runtime();
        service.executeRun("run_fixture");
        assertThat(repository.findSession("run_fixture").orElseThrow().status()).isEqualTo(AgentRunStatus.FAILED);
        assertThat(reads).hasValue(1);
        service.retry("usr_fixture", "run_fixture");
        executor.runNext();
        assertThat(reads).hasValue(1);
        assertThat(writes).hasValue(0);
        assertThat(repository.listApprovals("run_fixture", null)).isEmpty();
        assertThat(repository.listInvocations("run_fixture")).hasSize(1);
        var run = repository.findSession("run_fixture").orElseThrow();
        assertThat(run.attemptCount()).isEqualTo(1);
        assertThat(run.status()).isEqualTo(AgentRunStatus.FAILED);
        assertThat(run.errorMessage()).containsIgnoringCase("call ID");
    }

    private void scripted(List<Map<String, Object>> turns) throws Exception {
        var adapter = new MockAgentTurnGateway(mapper, clock, mapper.writeValueAsString(Map.of("turns", turns)));
        gateway = new AgentTurnGateway() {
            @Override public AgentTurnResult turn(AgentTurnRequest request) { return adapter.turn(request); }
            @Override public ProviderCapability detectCapability(String workspaceId, String agentKey) {
                return adapter.detectCapability(workspaceId, agentKey);
            }
        };
    }

    private Map<String, Object> legacy(String name) {
        return Map.of("function_call", Map.of("name", name, "arguments", "{}"));
    }

    private Map<String, Object> modern(String name) {
        return Map.of("tool_calls", List.of(Map.of("id", "reused_call", "type", "function",
                "function", Map.of("name", name, "arguments", "{}"))));
    }

    private void serve(List<Map<String, Object>> responses) throws Exception {
        var index = new AtomicInteger();
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v1/chat/completions", exchange -> {
            exchange.getRequestBody().readAllBytes();
            var message = responses.get(Math.min(index.getAndIncrement(), responses.size() - 1));
            var body = mapper.writeValueAsString(Map.of("choices", List.of(Map.of("message", message))))
                    .getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, body.length);
            exchange.getResponseBody().write(body);
            exchange.close();
        });
        server.start();
        var target = new AgentExecutionTarget("OPENCLAW", "http://127.0.0.1:" + server.getAddress().getPort(), null);
        var adapter = new OpenClawTurnGateway(mapper, clock);
        gateway = new AgentTurnGateway() {
            @Override public AgentTurnResult turn(AgentTurnRequest request) { return adapter.turn(request, target); }
            @Override public ProviderCapability detectCapability(String workspaceId, String agentKey) {
                return new ProviderCapability(true, "local protocol fixture", clock.instant().toString());
            }
        };
    }

    private AgentRuntimeService runtime() {
        return new AgentRuntimeService(repository, null, null, null, mock(JdbcWorkspaceRepository.class),
                mock(WorkspaceAccessGuard.class), contexts, gateway,
                new ProviderCapabilityService(repository, gateway, clock), tools,
                new ConnectorResolver(connectors), mock(RealtimeBroadcaster.class), mapper, clock, executor, 8);
    }

    private record CountingTool(String key, AtomicInteger executions, boolean approval) implements AgentTool {
        @Override public ToolDescriptor descriptor() {
            return new ToolDescriptor(key, key, key, Map.of(),
                    approval ? ToolPolicy.Permission.APPROVAL : ToolPolicy.Permission.AUTO,
                    approval ? ToolPolicy.Risk.INTERNAL_WRITE : ToolPolicy.Risk.READ_ONLY, true, null);
        }
        @Override public ToolResult invoke(ToolContext context, Map<String, Object> input) {
            executions.incrementAndGet();
            return ToolResult.ok(Map.of("tool", key), "Completed " + key);
        }
    }

    private static final class HoldingExecutor extends AbstractExecutorService {
        private final List<Runnable> commands = new ArrayList<>();
        private boolean shutdown;
        @Override public void execute(Runnable command) { commands.add(command); }
        @Override public void shutdown() { shutdown = true; }
        @Override public List<Runnable> shutdownNow() { shutdown = true; return List.copyOf(commands); }
        @Override public boolean isShutdown() { return shutdown; }
        @Override public boolean isTerminated() { return shutdown; }
        @Override public boolean awaitTermination(long timeout, TimeUnit unit) { return shutdown; }
        void runNext() { commands.removeFirst().run(); }
    }
}
