package com.microflow.agent.runtime.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import tools.jackson.databind.ObjectMapper;
import com.microflow.agent.runtime.domain.gateway.AgentTurnGateway;
import com.microflow.agent.runtime.domain.gateway.AgentTurnRequest;
import com.microflow.agent.runtime.domain.gateway.AgentTurnResult;
import com.microflow.agent.runtime.domain.gateway.ProviderCapability;
import com.microflow.agent.runtime.domain.gateway.TurnMessage;
import com.microflow.agent.runtime.domain.model.AgentConnector;
import com.microflow.agent.runtime.domain.model.AgentRunSession;
import com.microflow.agent.runtime.domain.model.AgentRunStatus;
import com.microflow.agent.runtime.domain.model.AgentToolInvocation;
import com.microflow.agent.runtime.domain.model.ConnectorKind;
import com.microflow.agent.runtime.domain.model.ConnectorSharingScope;
import com.microflow.agent.runtime.domain.model.ConnectorStatus;
import com.microflow.agent.runtime.domain.model.ToolCallRequest;
import com.microflow.agent.runtime.domain.model.ToolDescriptor;
import com.microflow.agent.runtime.domain.model.ToolPolicy;
import com.microflow.agent.runtime.domain.tool.AgentTool;
import com.microflow.agent.runtime.domain.tool.ToolContext;
import com.microflow.agent.runtime.domain.tool.ToolResult;
import com.microflow.agent.runtime.infrastructure.persistence.JdbcAgentRuntimeRepository;
import com.microflow.agent.runtime.infrastructure.persistence.JdbcConnectorRepository;
import com.microflow.agent.runtime.infrastructure.tool.ToolRegistry;
import com.microflow.bootstrap.schema.SchemaMaintenanceInitializer;
import com.microflow.realtime.broadcaster.RealtimeBroadcaster;
import com.microflow.workspace.application.service.WorkspaceAccessGuard;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.AbstractExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import com.microflow.common.jdbc.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

class ContextProviderRuntimeRepairTest {
    @TempDir Path directory;
    private final AdvancingClock clock = new AdvancingClock();
    private final ObjectMapper mapper = new ObjectMapper();
    private final AgentTurnGateway gateway = mock(AgentTurnGateway.class);
    private final ToolRegistry tools = mock(ToolRegistry.class);
    private final AgentContextBuilder contexts = mock(AgentContextBuilder.class);
    private final JdbcConnectorRepository connectorRepository = mock(JdbcConnectorRepository.class);
    private final HoldingExecutor executor = new HoldingExecutor();
    private final AtomicInteger actions = new AtomicInteger();
    private JdbcTemplate jdbc;
    private JdbcAgentRuntimeRepository repository;
    private AgentRuntimeService service;

    @BeforeEach
    void initialize() {
        jdbc = new JdbcTemplate(new DriverManagerDataSource("jdbc:sqlite:" + directory.resolve("runtime.db")));
        new SchemaMaintenanceInitializer(jdbc).initializeSchema();
        repository = new JdbcAgentRuntimeRepository(jdbc, clock, mapper);
        when(gateway.detectCapability(anyString(), anyString())).thenAnswer(invocation ->
                new ProviderCapability(true, "fixture", clock.instant().toString()));
        when(contexts.build(any())).thenReturn(new AgentContextBuilder.RunContext("context", List.of(), "context"));
        when(connectorRepository.listByWorkspace("ws_fixture")).thenReturn(List.of());
        when(tools.descriptorsFor(any())).thenReturn(List.of(new CountingTool().descriptor()));
        when(tools.require("fixture.write")).thenReturn(new CountingTool());
        service = new AgentRuntimeService(repository, null, null, null, mock(JdbcWorkspaceRepository.class),
                mock(WorkspaceAccessGuard.class), contexts, gateway,
                new ProviderCapabilityService(repository, gateway, clock), tools,
                new ConnectorResolver(connectorRepository), mock(RealtimeBroadcaster.class), mapper, clock, executor, 8);
    }

    @Test
    void readOnlyWebdavOffersListButDoesNotOfferWrite() {
        var request = executeCatalog(List.of(connector("own", "usr_fixture", ConnectorSharingScope.PRIVATE,
                List.of(), true, false)));
        assertThat(request.tools()).extracting(ToolDescriptor::key).containsExactly("webdav.list");
    }

    @Test
    void writeOnlyWebdavOffersWriteButDoesNotOfferList() {
        var request = executeCatalog(List.of(connector("own", "usr_fixture", ConnectorSharingScope.PRIVATE,
                List.of(), false, true)));
        assertThat(request.tools()).extracting(ToolDescriptor::key).containsExactly("webdav.write");
    }

    @Test
    void hiddenPrivateAndAgentDisallowedConnectorsCannotEnableEitherDirection() {
        var request = executeCatalog(List.of(
                connector("private", "usr_other", ConnectorSharingScope.PRIVATE, List.of(), true, true),
                connector("allowlist", "usr_fixture", ConnectorSharingScope.PRIVATE, List.of("another-agent"), true, true)));
        assertThat(request.tools()).isEmpty();
    }

    @Test
    void ownConnectorWinsWhileSharedConnectorCanSupplyTheOtherDirection() {
        var shared = connector("shared", "usr_other", ConnectorSharingScope.WORKSPACE, List.of(), true, true);
        var own = connector("own", "usr_fixture", ConnectorSharingScope.PRIVATE, List.of(), true, false);
        when(connectorRepository.listByWorkspace("ws_fixture")).thenReturn(List.of(shared, own));
        when(connectorRepository.findCredentials(anyString())).thenReturn(Map.of());
        var resolver = new ConnectorResolver(connectorRepository);
        assertThat(resolver.resolve("ws_fixture", "usr_fixture", "assistant", ConnectorKind.WEBDAV, false)
                .orElseThrow().connector().id()).isEqualTo("own");
        assertThat(resolver.resolve("ws_fixture", "usr_fixture", "assistant", ConnectorKind.WEBDAV, true)
                .orElseThrow().connector().id()).isEqualTo("shared");
        assertThat(executeCatalog(List.of(shared, own)).tools()).extracting(ToolDescriptor::key)
                .containsExactly("webdav.list", "webdav.write");
    }

    @ParameterizedTest
    @ValueSource(strings = {"{broken", "null", "[]", "17", "", "{} trailing"})
    void corruptedPersistedInvocationFailsBeforeUsingADefaultTarget(String corruptJson) {
        startWaitingWrite();
        var approval = repository.listApprovals("run_fixture", null).getFirst();
        service.decideApproval("usr_fixture", "run_fixture", approval.id(), "APPROVE", null);
        jdbc.update("UPDATE agent_tool_invocations SET input_json = ? WHERE session_id = ?", corruptJson, "run_fixture");
        executor.runNext();
        assertThat(actions).hasValue(0);
        assertThat(repository.findSession("run_fixture").orElseThrow().status()).isEqualTo(AgentRunStatus.FAILED);
        assertThat(repository.listInvocations("run_fixture").getFirst().status()).isEqualTo(AgentToolInvocation.Status.FAILED);
    }

    @Test
    void validPersistedObjectStillExecutesOnceAfterApproval() {
        startWaitingWrite();
        var approval = repository.listApprovals("run_fixture", null).getFirst();
        service.decideApproval("usr_fixture", "run_fixture", approval.id(), "APPROVE", null);
        executor.runNext();
        assertThat(actions).hasValue(1);
        assertThat(repository.findSession("run_fixture").orElseThrow().status()).isEqualTo(AgentRunStatus.SUCCEEDED);
    }

    @Test
    void unsupportedCapabilityRemainsStickyAndCachesAreIsolatedByWorkspaceAndAgent() {
        var probes = new AtomicInteger();
        when(gateway.detectCapability(anyString(), anyString())).thenAnswer(invocation -> {
            probes.incrementAndGet();
            return ProviderCapability.unsupported(invocation.getArgument(0) + ":" + invocation.getArgument(1), clock.instant().toString());
        });
        var capability = new ProviderCapabilityService(repository, gateway, clock);
        assertThat(capability.resolve("ws_a", "agent_a").detail()).isEqualTo("ws_a:agent_a");
        clock.advance(Duration.ofHours(23));
        assertThat(capability.resolve("ws_a", "agent_a").supportsToolCalls()).isFalse();
        assertThat(probes).hasValue(1);
        assertThat(capability.resolve("ws_b", "agent_a").detail()).isEqualTo("ws_b:agent_a");
        assertThat(capability.resolve("ws_a", "agent_b").detail()).isEqualTo("ws_a:agent_b");
        assertThat(probes).hasValue(3);
        clock.advance(Duration.ofHours(2));
        capability.resolve("ws_a", "agent_a");
        assertThat(probes).hasValue(4);
    }

    @Test
    void capabilityExpiresAtTheExactTwentyFourHourBoundary() {
        var probes = new AtomicInteger();
        when(gateway.detectCapability(anyString(), anyString())).thenAnswer(invocation -> {
            probes.incrementAndGet();
            return new ProviderCapability(true, "probe-" + probes.get(), clock.instant().toString());
        });
        var capability = new ProviderCapabilityService(repository, gateway, clock);
        capability.resolve("ws_fixture", "assistant");
        clock.advance(Duration.ofHours(24));
        assertThat(capability.resolve("ws_fixture", "assistant").detail()).isEqualTo("probe-2");
    }

    private AgentTurnRequest executeCatalog(List<AgentConnector> connectors) {
        when(connectorRepository.listByWorkspace("ws_fixture")).thenReturn(connectors);
        when(tools.descriptorsFor(any())).thenAnswer(invocation -> {
            java.util.Set<ConnectorKind> kinds = invocation.getArgument(0);
            return kinds.contains(ConnectorKind.WEBDAV) ? List.of(
                    new ToolDescriptor("webdav.list", "List", "Read", Map.of(), ToolPolicy.Permission.AUTO,
                            ToolPolicy.Risk.READ_ONLY, true, "WEBDAV"),
                    new ToolDescriptor("webdav.write", "Write", "Write", Map.of(), ToolPolicy.Permission.APPROVAL,
                            ToolPolicy.Risk.EXTERNAL_WRITE, false, "WEBDAV")) : List.of();
        });
        var sent = new AtomicReference<AgentTurnRequest>();
        when(gateway.turn(any())).thenAnswer(invocation -> {
            sent.set(invocation.getArgument(0));
            return AgentTurnResult.text("catalog observed");
        });
        insertRun();
        service.executeRun("run_fixture");
        assertThat(repository.findSession("run_fixture").orElseThrow().status()).isEqualTo(AgentRunStatus.SUCCEEDED);
        return sent.get();
    }

    private void startWaitingWrite() {
        when(gateway.turn(any())).thenReturn(AgentTurnResult.toolCalls(
                List.of(new ToolCallRequest("call_fixture", "fixture.write", Map.of())), "Write"), AgentTurnResult.text("Finished"));
        insertRun();
        service.executeRun("run_fixture");
        assertThat(repository.findSession("run_fixture").orElseThrow().status()).isEqualTo(AgentRunStatus.WAITING_APPROVAL);
    }

    private void insertRun() {
        repository.insertSession(new AgentRunSession("run_fixture", "ws_fixture", null, null, null, "usr_fixture", "assistant",
                "TASK", AgentRunStatus.QUEUED, "fixture", null, null, "NONE", null, 0, 0, 0,
                clock.instant().toString(), null, null, clock.instant().toString()));
    }

    private AgentConnector connector(String id, String owner, ConnectorSharingScope scope, List<String> agents,
                                     boolean read, boolean write) {
        return new AgentConnector(id, "ws_fixture", owner, ConnectorKind.WEBDAV, id, Map.of(), List.of(), scope, List.of(),
                agents, ConnectorStatus.ACTIVE, read, write, null, null, clock.instant().toString(), clock.instant().toString());
    }

    private final class CountingTool implements AgentTool {
        @Override public ToolDescriptor descriptor() {
            return new ToolDescriptor("fixture.write", "Write", "Write fixture", Map.of(), ToolPolicy.Permission.APPROVAL,
                    ToolPolicy.Risk.EXTERNAL_WRITE, false, null);
        }
        @Override public ToolResult invoke(ToolContext context, Map<String, Object> input) {
            actions.incrementAndGet();
            return ToolResult.ok(Map.of("written", true), "Written");
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

    private static final class AdvancingClock extends Clock {
        private Instant now = Instant.parse("2026-11-24T00:00:00Z");
        @Override public ZoneId getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(ZoneId zone) { return this; }
        @Override public Instant instant() { return now; }
        void advance(Duration duration) { now = now.plus(duration); }
    }
}
