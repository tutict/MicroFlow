package com.microflow.agent.runtime;

import static org.assertj.core.api.Assertions.assertThat;

import tools.jackson.databind.ObjectMapper;
import com.microflow.agent.runtime.application.AgentRuntimeService;
import com.microflow.agent.runtime.domain.model.AgentRunStatus;
import com.microflow.agent.runtime.domain.gateway.AgentTurnRequest;
import com.microflow.agent.runtime.domain.gateway.AgentTurnResult;
import com.microflow.agent.runtime.infrastructure.persistence.JdbcAgentRuntimeRepository;
import com.microflow.agent.runtime.infrastructure.provider.MockAgentTurnGateway;
import com.microflow.testing.MicroFlowApiTestSupport;
import com.microflow.testing.QuarkusRestTemplate;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.QuarkusTestProfile;
import io.quarkus.test.junit.TestProfile;
import jakarta.inject.Inject;
import jakarta.enterprise.inject.Alternative;
import jakarta.inject.Singleton;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Clock;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.junit.jupiter.api.Test;

@QuarkusTest
@TestProfile(AgentRuntimeContinuationTests.Profile.class)
class AgentRuntimeContinuationTests extends MicroFlowApiTestSupport {
    private static final Path DATABASE = database();

    public static class Profile extends AgentRuntimeApiTests.Profile implements QuarkusTestProfile {
        @Override
        public Map<String, String> getConfigOverrides() {
            var config = new HashMap<>(super.getConfigOverrides());
            config.put("microflow.database.path", DATABASE.toString());
            config.put("microflow.agent.runtime.max-steps", "1");
            return config;
        }

        @Override
        public Set<Class<?>> getEnabledAlternatives() {
            return Set.of(BlockingMockGateway.class);
        }
    }

    private final QuarkusRestTemplate http = new QuarkusRestTemplate();
    @Inject ObjectMapper json;
    @Inject AgentRuntimeService service;
    @Inject JdbcAgentRuntimeRepository runtime;
    @Inject BlockingMockGateway model;

    @Test
    void approvalContinuationDoesNotResetTheModelTurnBudget() {
        var fixture = start();
        awaitStatus(fixture.runId(), AgentRunStatus.WAITING_APPROVAL);
        var approval = runtime.findPendingApproval(fixture.runId()).orElseThrow();
        service.decideApproval(fixture.owner().userId(), fixture.runId(), approval.id(), "APPROVE", "Review complete");
        awaitStatus(fixture.runId(), AgentRunStatus.FAILED);
        assertThat(service.requireRun(fixture.runId()).errorMessage()).contains("maximum of 1");
        assertThat(runtime.listSteps(fixture.runId()).stream().filter(step -> "MODEL_TURN".equals(step.stepKind())))
                .hasSize(1);
    }

    @Test
    void cancellationDuringAModelCallCannotLeaveANewPendingApproval() throws InterruptedException {
        var gate = model.blockTurns();
        Fixture fixture;
        try {
            fixture = start();
            assertThat(gate.entered().await(5, TimeUnit.SECONDS))
                    .as("the model call started while its result is still blocked").isTrue();
            service.cancel(fixture.owner().userId(), fixture.runId());
        } finally {
            model.releaseTurns(gate);
        }
        Thread.sleep(700);
        assertThat(service.requireRun(fixture.runId()).status()).isEqualTo(AgentRunStatus.CANCELLED);
        assertThat(runtime.listApprovals(fixture.runId(), "PENDING")).isEmpty();
        assertThat(runtime.listArtifacts(fixture.runId())).isEmpty();
    }

    @Alternative
    @Singleton
    public static class BlockingMockGateway extends MockAgentTurnGateway {
        private volatile ModelGate gate;

        @Inject
        public BlockingMockGateway(
                ObjectMapper json, Clock clock,
                @ConfigProperty(name = "microflow.agent.mock-plan") String plan
        ) {
            super(json, clock, plan);
        }

        public ModelGate blockTurns() {
            var next = new ModelGate(new CountDownLatch(1), new CountDownLatch(1));
            gate = next;
            return next;
        }

        public void releaseTurns(ModelGate current) {
            current.release().countDown();
            gate = null;
        }

        @Override
        public AgentTurnResult turn(AgentTurnRequest request) {
            var current = gate;
            if (current != null) {
                current.entered().countDown();
                try {
                    if (!current.release().await(10, TimeUnit.SECONDS)) {
                        throw new AssertionError("Test did not release the model call");
                    }
                } catch (InterruptedException exception) {
                    Thread.currentThread().interrupt();
                    throw new AssertionError(exception);
                }
            }
            return super.turn(request);
        }
    }

    public record ModelGate(CountDownLatch entered, CountDownLatch release) { }

    private Fixture start() {
        var owner = register(http, json, "continuation-" + System.nanoTime() + "@example.com", "Owner");
        var workspaceId = createWorkspace(http, json, owner, "Continuation");
        var taskId = createTaskId(http, json, owner, workspaceId, Map.of());
        var run = service.startTaskRun(owner.userId(), workspaceId, taskId, null, "Close the task");
        return new Fixture(owner, run.id());
    }

    private void awaitStatus(String id, AgentRunStatus expected) {
        var deadline = System.nanoTime() + Duration.ofSeconds(5).toNanos();
        while (System.nanoTime() < deadline) {
            var run = service.requireRun(id);
            if (run.status() == expected) return;
            if (run.status().isTerminal()) assertThat(run.status()).isEqualTo(expected);
            try { Thread.sleep(10); } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                throw new AssertionError(exception);
            }
        }
        throw new AssertionError("Run did not reach " + expected);
    }

    private record Fixture(Session owner, String runId) { }
    private static Path database() {
        try { return Files.createTempDirectory("microflow-continuation-").resolve("continuation.db").toAbsolutePath(); }
        catch (IOException exception) { throw new IllegalStateException(exception); }
    }
}
