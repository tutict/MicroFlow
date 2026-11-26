package com.microflow.agent.runtime.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.spy;
import static org.mockito.Mockito.when;

import tools.jackson.databind.ObjectMapper;
import com.microflow.agent.runtime.domain.gateway.AgentTurnGateway;
import com.microflow.agent.runtime.domain.gateway.AgentTurnResult;
import com.microflow.agent.runtime.domain.gateway.ProviderCapability;
import com.microflow.agent.runtime.domain.gateway.TurnMessage;
import com.microflow.agent.runtime.domain.model.AgentApproval;
import com.microflow.agent.runtime.domain.model.AgentApprovalStatus;
import com.microflow.agent.runtime.domain.model.AgentRunSession;
import com.microflow.agent.runtime.domain.model.AgentRunStatus;
import com.microflow.agent.runtime.domain.model.AgentToolInvocation;
import com.microflow.agent.runtime.domain.model.ToolDescriptor;
import com.microflow.agent.runtime.domain.model.ToolPolicy;
import com.microflow.agent.runtime.domain.model.ToolCallRequest;
import com.microflow.agent.runtime.domain.tool.AgentTool;
import com.microflow.agent.runtime.domain.tool.ToolContext;
import com.microflow.agent.runtime.domain.tool.ToolResult;
import com.microflow.agent.runtime.infrastructure.persistence.JdbcAgentRuntimeRepository;
import com.microflow.agent.runtime.infrastructure.tool.ToolRegistry;
import com.microflow.bootstrap.schema.SchemaMaintenanceInitializer;
import com.microflow.common.error.ConcurrentModificationException;
import com.microflow.realtime.broadcaster.RealtimeBroadcaster;
import com.microflow.workspace.application.service.WorkspaceAccessGuard;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.AbstractExecutorService;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import com.microflow.common.jdbc.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

/** Controlled worker interleavings against a real, isolated SQLite database. */
class AgentRuntimeSafetyTest {

    @TempDir Path directory;
    private final Clock clock = Clock.systemUTC();
    private final ObjectMapper mapper = new ObjectMapper();
    private final HoldingExecutor executor = new HoldingExecutor();
    private final AtomicInteger actions = new AtomicInteger();
    private final AgentTurnGateway gateway = mock(AgentTurnGateway.class);
    private final AgentContextBuilder contexts = mock(AgentContextBuilder.class);
    private final ToolRegistry tools = mock(ToolRegistry.class);
    private JdbcTemplate jdbc;
    private JdbcAgentRuntimeRepository repository;
    private AgentRuntimeService service;

    @BeforeEach
    void initialize() {
        jdbc = new JdbcTemplate(new DriverManagerDataSource(
                "jdbc:sqlite:" + directory.resolve("runtime.db")));
        new SchemaMaintenanceInitializer(jdbc).initializeSchema();
        repository = new JdbcAgentRuntimeRepository(jdbc, clock, mapper);
        when(gateway.detectCapability(anyString(), anyString()))
                .thenReturn(new ProviderCapability(true, "fixture", now()));
        when(contexts.build(any())).thenReturn(
                new AgentContextBuilder.RunContext("fixture context", List.of(), "fixture"));
        when(tools.require("fixture.write")).thenReturn(new CountingTool());
        when(tools.descriptorsFor(any())).thenReturn(List.of(new CountingTool().descriptor()));
        service = runtime(repository);
    }

    @Test
    void startupRecoversEveryPageAndSchedulesQueuedRunsOnlyOnce() {
        for (var index = 0; index < 205; index++) {
            insertRun("run_running_" + index, AgentRunStatus.RUNNING);
            insertRun("run_context_" + index, AgentRunStatus.CONTEXT_BUILDING);
            insertRun("run_queued_" + index, AgentRunStatus.QUEUED);
        }
        insertRun("run_waiting", AgentRunStatus.WAITING_APPROVAL);

        var report = service.recoverAfterRestart();

        assertThat(report.interruptedRuns()).isEqualTo(410);
        assertThat(report.requeuedRuns()).isEqualTo(205);
        assertThat(executor.commands).hasSize(205);
        assertThat(jdbc.queryForObject(
                "SELECT COUNT(*) FROM agent_run_sessions WHERE status = 'FAILED'", Integer.class))
                .isEqualTo(410);
        assertThat(repository.findSession("run_waiting").orElseThrow().status())
                .isEqualTo(AgentRunStatus.WAITING_APPROVAL);
    }

    @ParameterizedTest
    @ValueSource(strings = {"EXTERNAL_WRITE", "DESTRUCTIVE"})
    void restartFreezesAnExternalActionWhoseResultWasNotPersisted(String risk) {
        insertRun("run_crashed", AgentRunStatus.RUNNING);
        var step = repository.createStep("run_crashed", "TOOL", "RUNNING", "assistant", "SMTP", "{}");
        repository.insertInvocation(new AgentToolInvocation(
                "inv_crashed", "run_crashed", "ws_fixture", step.id(), "mail.send", "mail_once",
                AgentToolInvocation.Status.APPROVED, risk, "{}", null, null, null,
                0, now(), null));

        service.recoverAfterRestart();

        assertThat(repository.findInvocationByKey("run_crashed", "mail_once").orElseThrow().status())
                .isEqualTo(AgentToolInvocation.Status.UNKNOWN);
        assertThat(repository.findSession("run_crashed").orElseThrow().status())
                .isEqualTo(AgentRunStatus.FAILED);
        assertThat(repository.listSteps("run_crashed"))
                .noneSatisfy(value -> assertThat(value.status()).isEqualTo("RUNNING"));
        assertThatThrownBy(() -> service.retry("usr_fixture", "run_crashed"))
                .isInstanceOf(ConcurrentModificationException.class);
        assertThat(executor.commands).isEmpty();
        assertThat(repository.findSession("run_crashed").orElseThrow().attemptCount()).isZero();
    }

    @Test
    void unsupportedProviderCannotCreateACallOrApprovalFromStructuredOutput() {
        when(gateway.detectCapability(anyString(), anyString()))
                .thenReturn(ProviderCapability.unsupported("disabled", now()));
        when(gateway.turn(any())).thenReturn(AgentTurnResult.toolCalls(
                List.of(new ToolCallRequest("call_disabled", "fixture.write", Map.of())), "Write"));
        insertRun("run_disabled", AgentRunStatus.QUEUED);

        service.executeRun("run_disabled");

        assertThat(repository.findSession("run_disabled").orElseThrow().status()).isEqualTo(AgentRunStatus.FAILED);
        assertThat(repository.listInvocations("run_disabled")).isEmpty();
        assertThat(repository.listApprovals("run_disabled", null)).isEmpty();
        assertThat(actions).hasValue(0);
    }

    @Test
    void structuredOutputCannotCallAToolOutsideTheOfferedCatalog() {
        when(tools.descriptorsFor(any())).thenReturn(List.of());
        when(gateway.turn(any())).thenReturn(AgentTurnResult.toolCalls(
                List.of(new ToolCallRequest("call_hidden", "fixture.write", Map.of())), "Write"));
        insertRun("run_hidden", AgentRunStatus.QUEUED);

        service.executeRun("run_hidden");

        assertThat(repository.findSession("run_hidden").orElseThrow().status()).isEqualTo(AgentRunStatus.FAILED);
        assertThat(repository.listInvocations("run_hidden")).isEmpty();
        assertThat(repository.listApprovals("run_hidden", null)).isEmpty();
        assertThat(actions).hasValue(0);
    }

    @Test
    void aProviderWithoutToolsCanStillFinishWithPlainText() {
        when(gateway.detectCapability(anyString(), anyString()))
                .thenReturn(ProviderCapability.unsupported("disabled", now()));
        when(gateway.turn(any())).thenReturn(AgentTurnResult.text("A plain text answer."));
        insertRun("run_text", AgentRunStatus.QUEUED);

        service.executeRun("run_text");

        assertThat(repository.findSession("run_text").orElseThrow().status()).isEqualTo(AgentRunStatus.SUCCEEDED);
        assertThat(repository.listInvocations("run_text")).isEmpty();
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "null", "{}", "[", "[{}]",
            "[{\"callId\":\"call\",\"toolKey\":\"fixture.write\",\"input\":null}]",
            "[{\"callId\":\"call\",\"toolKey\":\"fixture.write\",\"input\":{}},{\"callId\":\"call\",\"toolKey\":\"fixture.write\",\"input\":{}}]",
            "[{\"callId\":\"call\",\"toolKey\":\"fixture.write\",\"input\":{}}] {}"
    })
    void malformedPersistedCallsCannotBeSilentlyReadAsNoActions(String damaged) {
        insertRun("run_damaged", AgentRunStatus.QUEUED);
        repository.appendMessage("run_damaged", new TurnMessage("assistant", "Stored request",
                List.of(new ToolCallRequest("call", "fixture.write", Map.of())), null));
        jdbc.update("UPDATE agent_run_messages SET tool_calls_json = ? WHERE session_id = ?", damaged, "run_damaged");
        when(gateway.turn(any())).thenReturn(AgentTurnResult.text("Finished."));

        service.executeRun("run_damaged");

        assertThat(repository.findSession("run_damaged").orElseThrow().status()).isEqualTo(AgentRunStatus.FAILED);
        assertThat(actions).hasValue(0);
        assertThat(repository.listApprovals("run_damaged", null)).isEmpty();
    }

    @Test
    void concurrentRetriesHaveOneWinnerAndOneScheduledWorker() throws Exception {
        insertRun("run_retry", AgentRunStatus.FAILED);
        var spyRepository = spy(repository);
        var readers = new CyclicBarrier(2);
        doAnswer(invocation -> {
            var snapshot = repository.findSession("run_retry");
            if (snapshot.orElseThrow().status() == AgentRunStatus.FAILED) {
                readers.await(5, TimeUnit.SECONDS);
            }
            return snapshot;
        }).when(spyRepository).findSession("run_retry");
        var retryService = runtime(spyRepository);
        try (var callers = Executors.newFixedThreadPool(2)) {
            var first = callers.submit(() -> requestRetry(retryService));
            var second = callers.submit(() -> requestRetry(retryService));
            assertThat(List.of(first.get(10, TimeUnit.SECONDS), second.get(10, TimeUnit.SECONDS)))
                    .containsExactlyInAnyOrder("accepted", "conflict");
        }
        assertThat(repository.findSession("run_retry").orElseThrow().attemptCount()).isEqualTo(1);
        assertThat(executor.commands).hasSize(1);
    }

    @Test
    void aLateRetryCannotResetTheFirstWorkerAlreadyRunning() {
        insertRun("run_late_retry", AgentRunStatus.FAILED);
        repository.resetForRetry("run_late_retry");
        repository.updateStatus("run_late_retry", AgentRunStatus.QUEUED, AgentRunStatus.RUNNING,
                null, now(), null);

        repository.resetForRetry("run_late_retry");

        var run = repository.findSession("run_late_retry").orElseThrow();
        assertThat(run.status()).isEqualTo(AgentRunStatus.RUNNING);
        assertThat(run.attemptCount()).isEqualTo(1);
    }

    @Test
    void cancellationWinningBeforeToolAdmissionPreventsTheAction() {
        insertRun("run_cancel", AgentRunStatus.WAITING_APPROVAL);
        var step = repository.createStep("run_cancel", "APPROVAL", "RUNNING", "assistant", "Approve", "{}");
        repository.insertApproval(new AgentApproval(
                "approval_cancel", "run_cancel", "ws_fixture", step.id(), "fixture.write", "Write",
                "fixture", "EXTERNAL_WRITE", "One write", "{}", AgentApprovalStatus.PENDING,
                null, null, now(), null));
        repository.insertInvocation(new AgentToolInvocation(
                "inv_cancel", "run_cancel", "ws_fixture", step.id(), "fixture.write", "call_cancel",
                AgentToolInvocation.Status.AWAITING_APPROVAL, "EXTERNAL_WRITE", "{}", null,
                "approval_cancel", null, 0, now(), null));
        var cancelOnLookup = new AtomicBoolean(false);
        when(tools.require("fixture.write")).thenAnswer(invocation -> {
            if (cancelOnLookup.compareAndSet(true, false)) {
                service.cancel("usr_fixture", "run_cancel");
            }
            return new CountingTool();
        });
        service.decideApproval("usr_fixture", "run_cancel", "approval_cancel", "APPROVE", null);
        cancelOnLookup.set(true);

        executor.runNext();

        assertThat(actions).hasValue(0);
        assertThat(repository.findSession("run_cancel").orElseThrow().status())
                .isEqualTo(AgentRunStatus.CANCELLED);
        assertThat(repository.findInvocationByKey("run_cancel", "call_cancel").orElseThrow().status())
                .isEqualTo(AgentToolInvocation.Status.CANCELLED);
    }

    @ParameterizedTest
    @ValueSource(strings = {"SUCCEEDED", "UNKNOWN"})
    void cancellationAfterInvocationStartsRetainsItsActualOutcomeWithoutRepeating(String outcome) throws Exception {
        insertRun("run_started", AgentRunStatus.WAITING_APPROVAL);
        var step = repository.createStep("run_started", "APPROVAL", "RUNNING", "assistant", "Approve", "{}");
        repository.insertApproval(new AgentApproval(
                "approval_started", "run_started", "ws_fixture", step.id(), "fixture.write", "Write",
                "fixture", "EXTERNAL_WRITE", "One write", "{}", AgentApprovalStatus.PENDING,
                null, null, now(), null));
        repository.insertInvocation(new AgentToolInvocation(
                "inv_started", "run_started", "ws_fixture", step.id(), "fixture.write", "call_started",
                AgentToolInvocation.Status.AWAITING_APPROVAL, "EXTERNAL_WRITE", "{}", null,
                "approval_started", null, 0, now(), null));
        var entered = new CountDownLatch(1);
        var finish = new CountDownLatch(1);
        when(tools.require("fixture.write")).thenReturn(new AgentTool() {
            @Override public ToolDescriptor descriptor() { return new CountingTool().descriptor(); }
            @Override public ToolResult invoke(ToolContext context, Map<String, Object> input) {
                actions.incrementAndGet();
                entered.countDown();
                try {
                    if (!finish.await(5, TimeUnit.SECONDS)) throw new IllegalStateException("Fixture timed out");
                } catch (InterruptedException exception) {
                    Thread.currentThread().interrupt();
                    throw new IllegalStateException(exception);
                }
                return "UNKNOWN".equals(outcome) ? ToolResult.unknown("Remote result could not be confirmed")
                        : ToolResult.ok(Map.of("written", true), "Written");
            }
        });
        service.decideApproval("usr_fixture", "run_started", "approval_started", "APPROVE", null);
        try (var worker = Executors.newSingleThreadExecutor()) {
            var active = worker.submit(executor::runNext);
            try {
                assertThat(entered.await(5, TimeUnit.SECONDS)).isTrue();
                service.cancel("usr_fixture", "run_started");
            } finally { finish.countDown(); }
            active.get(10, TimeUnit.SECONDS);
        }
        assertThat(actions).hasValue(1);
        assertThat(repository.findSession("run_started").orElseThrow().status()).isEqualTo(AgentRunStatus.CANCELLED);
        var invocation = repository.findInvocationByKey("run_started", "call_started").orElseThrow();
        assertThat(invocation.status()).isEqualTo(AgentToolInvocation.Status.valueOf(outcome));
        assertThat(repository.listSteps("run_started").stream().filter(value -> "TOOL".equals(value.stepKind())))
                .singleElement().satisfies(value -> assertThat(value.status())
                        .isEqualTo("UNKNOWN".equals(outcome) ? "FAILED" : "COMPLETED"));
        service.recoverAfterRestart();
        assertThat(executor.commands).isEmpty();
        assertThat(actions).hasValue(1);
        assertThat(repository.findSession("run_started").orElseThrow().status()).isEqualTo(AgentRunStatus.CANCELLED);
    }

    private String requestRetry(AgentRuntimeService runtime) {
        try {
            runtime.retry("usr_fixture", "run_retry");
            return "accepted";
        } catch (ConcurrentModificationException exception) {
            return "conflict";
        }
    }

    private AgentRuntimeService runtime(JdbcAgentRuntimeRepository runtimeRepository) {
        return new AgentRuntimeService(runtimeRepository, null, null, null,
                mock(JdbcWorkspaceRepository.class), mock(WorkspaceAccessGuard.class), contexts, gateway,
                new ProviderCapabilityService(runtimeRepository, gateway, clock), tools,
                mock(ConnectorResolver.class), mock(RealtimeBroadcaster.class), mapper, clock, executor, 8);
    }

    private void insertRun(String id, AgentRunStatus status) {
        repository.insertSession(new AgentRunSession(
                id, "ws_fixture", null, null, null, "usr_fixture", "assistant", "TASK", status,
                "fixture goal", null, null, "NONE", null, 0, 0, 0, now(), null, null, now()));
    }

    private String now() { return Instant.now(clock).toString(); }

    private final class CountingTool implements AgentTool {
        @Override public ToolDescriptor descriptor() {
            return new ToolDescriptor("fixture.write", "Fixture write", "Fixture", Map.of(),
                    ToolPolicy.Permission.APPROVAL, ToolPolicy.Risk.EXTERNAL_WRITE, false, null);
        }

        @Override public ToolResult invoke(ToolContext context, Map<String, Object> input) {
            actions.incrementAndGet();
            return ToolResult.ok(Map.of("written", true), "Written");
        }
    }

    private static final class HoldingExecutor extends AbstractExecutorService {
        private final List<Runnable> commands = java.util.Collections.synchronizedList(new ArrayList<>());
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
