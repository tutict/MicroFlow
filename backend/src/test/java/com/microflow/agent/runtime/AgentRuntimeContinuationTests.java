package com.microflow.agent.runtime;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.microflow.agent.runtime.application.AgentRuntimeService;
import com.microflow.agent.runtime.domain.model.AgentRunStatus;
import com.microflow.agent.runtime.infrastructure.persistence.JdbcAgentRuntimeRepository;
import com.microflow.testing.MicroFlowApiTestSupport;
import com.microflow.testing.QuarkusRestTemplate;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.QuarkusTestProfile;
import io.quarkus.test.junit.TestProfile;
import jakarta.inject.Inject;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
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
            config.put("microflow.agent.mock-delay", "PT0.5S");
            config.put("microflow.agent.runtime.max-steps", "1");
            return config;
        }
    }

    private final QuarkusRestTemplate http = new QuarkusRestTemplate();
    @Inject ObjectMapper json;
    @Inject AgentRuntimeService service;
    @Inject JdbcAgentRuntimeRepository runtime;

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
        var fixture = start();
        var deadline = System.nanoTime() + Duration.ofSeconds(5).toNanos();
        while (runtime.listSteps(fixture.runId()).stream()
                .noneMatch(step -> "MODEL_TURN".equals(step.stepKind()) && "RUNNING".equals(step.status()))) {
            assertThat(System.nanoTime()).isLessThan(deadline);
            Thread.sleep(5);
        }
        service.cancel(fixture.owner().userId(), fixture.runId());
        Thread.sleep(700);
        assertThat(service.requireRun(fixture.runId()).status()).isEqualTo(AgentRunStatus.CANCELLED);
        assertThat(runtime.listApprovals(fixture.runId(), "PENDING")).isEmpty();
        assertThat(runtime.listArtifacts(fixture.runId())).isEmpty();
    }

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
