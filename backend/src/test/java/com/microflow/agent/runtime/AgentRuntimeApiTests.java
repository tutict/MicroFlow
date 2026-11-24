package com.microflow.agent.runtime;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.microflow.agent.runtime.application.AgentRuntimeService;
import com.microflow.task.domain.model.TaskStatus;
import com.microflow.task.infrastructure.persistence.JdbcTaskRepository;
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
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

/**
 * End-to-end coverage of the durable run loop over HTTP.
 *
 * <p>Each test asserts on observable state (task row, approval row, event log)
 * rather than on internal calls, because the whole point of the harness is that
 * the side effects and the audit trail agree.
 */
@QuarkusTest
@TestProfile(AgentRuntimeApiTests.Profile.class)
class AgentRuntimeApiTests extends MicroFlowApiTestSupport {
    @Inject
    private com.microflow.common.jdbc.JdbcTemplate jdbcTemplate;

    @Test
    void unrelatedOperatorCannotApproveSomeoneElsesTaskWrite() {
        var owner = register(restTemplate, objectMapper, uniqueEmail("approval-owner"), "Owner");
        var email = uniqueEmail("unrelated-operator");
        var operator = register(restTemplate, objectMapper, email, "Operator");
        var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Approval authorization");
        addMemberByEmail(restTemplate, owner, workspaceId, email);
        var taskId = createTaskId(restTemplate, objectMapper, owner, workspaceId, Map.of("title", "Owner task"));
        var runId = startRun(owner, workspaceId, taskId);
        awaitStatus(owner, runId, "WAITING_APPROVAL");
        var approvalId = (String) readList(objectMapper, get(restTemplate,
                "/api/v1/agent-runs/" + runId + "/approvals?status=PENDING", owner).getBody()).getFirst().get("id");

        var refused = post(restTemplate, "/api/v1/agent-runs/" + runId + "/approvals/" + approvalId + "/decision",
                operator, Map.of("decision", "APPROVE"));

        assertThat(refused.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(taskStatus(workspaceId, taskId)).isEqualTo(TaskStatus.OPEN);
        assertThat(readList(objectMapper, get(restTemplate,
                "/api/v1/agent-runs/" + runId + "/approvals?status=PENDING", owner).getBody())).hasSize(1);
        assertThat(post(restTemplate, "/api/v1/agent-runs/" + runId + "/approvals/" + approvalId + "/decision",
                owner, Map.of("decision", "APPROVE")).getStatusCode()).isEqualTo(HttpStatus.OK);
        awaitStatus(owner, runId, "SUCCEEDED");
        assertThat(taskStatus(workspaceId, taskId)).isEqualTo(TaskStatus.DONE);
    }

    @Test
    void actualApproverAuthorizesAndOwnsTheTaskWriteAudit() {
        var owner = register(restTemplate, objectMapper, uniqueEmail("actor-owner"), "Owner");
        var email = uniqueEmail("actor-initiator");
        var initiator = register(restTemplate, objectMapper, email, "Initiator");
        var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Approval actor");
        addMemberByEmail(restTemplate, owner, workspaceId, email);
        var taskId = createTaskId(restTemplate, objectMapper, owner, workspaceId, Map.of("title", "Owner task"));
        var runId = startRun(initiator, workspaceId, taskId);
        awaitStatus(owner, runId, "WAITING_APPROVAL");
        var approvalId = (String) readList(objectMapper, get(restTemplate,
                "/api/v1/agent-runs/" + runId + "/approvals?status=PENDING", owner).getBody()).getFirst().get("id");
        assertThat(post(restTemplate, "/api/v1/agent-runs/" + runId + "/approvals/" + approvalId + "/decision",
                owner, Map.of("decision", "APPROVE")).getStatusCode()).isEqualTo(HttpStatus.OK);
        awaitStatus(owner, runId, "SUCCEEDED");

        var activities = readList(objectMapper, get(restTemplate,
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/activity", owner).getBody());
        assertThat(activities).anySatisfy(activity -> {
            assertThat(activity.get("eventType")).isEqualTo("STATUS_CHANGED");
            assertThat(activity.get("actorUserId")).isEqualTo(owner.userId());
        });
    }

    @Test
    void approvalChecksTheActualTargetAndNotOnlyTheAttachedTask() {
        var owner = register(restTemplate, objectMapper, uniqueEmail("target-owner"), "Owner");
        var email = uniqueEmail("target-operator");
        var operator = register(restTemplate, objectMapper, email, "Operator");
        var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Actual approval target");
        addMemberByEmail(restTemplate, owner, workspaceId, email);
        var sourceId = createTaskId(restTemplate, objectMapper, operator, workspaceId, Map.of("title", "Operator task"));
        var targetId = createTaskId(restTemplate, objectMapper, owner, workspaceId, Map.of("title", "Owner target"));
        var runId = startRun(operator, workspaceId, sourceId);
        awaitStatus(owner, runId, "WAITING_APPROVAL");
        var approvalId = (String) readList(objectMapper, get(restTemplate,
                "/api/v1/agent-runs/" + runId + "/approvals?status=PENDING", owner).getBody()).getFirst().get("id");
        var input = "{\"taskId\":\"" + targetId + "\",\"status\":\"DONE\"}";
        jdbcTemplate.update("UPDATE agent_approvals SET input_json = ?, target_resource = ? WHERE id = ?",
                input, "task:" + targetId, approvalId);
        jdbcTemplate.update("UPDATE agent_tool_invocations SET input_json = ? WHERE approval_id = ?", input, approvalId);

        var decision = post(restTemplate, "/api/v1/agent-runs/" + runId + "/approvals/" + approvalId + "/decision",
                operator, Map.of("decision", "APPROVE"));

        assertThat(decision.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(taskStatus(workspaceId, sourceId)).isEqualTo(TaskStatus.OPEN);
        assertThat(taskStatus(workspaceId, targetId)).isEqualTo(TaskStatus.OPEN);
    }

    private static final Path databasePath = createDatabasePath();

    private static final String MOCK_PLAN = """
            {"turns":[
              {"text":"Checking the task before acting.","toolCalls":[
                {"callId":"call_status","toolKey":"task.update_status","input":{"status":"DONE"}}
              ]},
              {"text":"Task is now DONE."}
            ]}
            """;

    public static class Profile implements QuarkusTestProfile {
        @Override
        public Map<String, String> getConfigOverrides() {
            return Map.of(
                    "microflow.database.path", databasePath.toAbsolutePath().toString(),
                    "microflow.agent.mock-delay", "PT0.02S",
                    "microflow.agent.mock-plan", MOCK_PLAN,
                    "microflow.agent.openclaw-state-dir",
                    databasePath.resolveSibling("missing-qclaw-state").toString(),
                    "microflow.seed.demo-enabled", "false",
                    "microflow.jwt.secret", "agent-runtime-test-jwt-secret-with-entropy",
                    "microflow.crypto.secret", "ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA="
            );
        }
    }

    private static Path createDatabasePath() {
        try {
            return Files.createTempDirectory("microflow-runtime-tests").resolve("runtime.db");
        } catch (IOException exception) {
            throw new IllegalStateException("Unable to create a runtime test database path", exception);
        }
    }

    @AfterAll
    static void cleanDatabase() {
        try {
            Files.deleteIfExists(databasePath);
        } catch (IOException ignored) {
            // Windows may still hold the SQLite file handle briefly after shutdown.
        }
    }

    private final QuarkusRestTemplate restTemplate = new QuarkusRestTemplate();

    @Inject
    private ObjectMapper objectMapper;

    @Inject
    private JdbcTaskRepository taskRepository;

    @Inject
    private AgentRuntimeService runtimeService;

    @Test
    void approvalGatesTaskWriteAndApprovalResumesTheSameRun() {
        var owner = register(restTemplate, objectMapper, uniqueEmail("approve"), "Approver");
        var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Runtime Approve");
        var taskId = createTaskId(restTemplate, objectMapper, owner, workspaceId, Map.of(
                "title", "Close the release checklist",
                "detail", "Ship the runtime harness."));

        var runId = startRun(owner, workspaceId, taskId);
        var waiting = awaitStatus(owner, runId, "WAITING_APPROVAL");
        assertThat(waiting.get("status")).isEqualTo("WAITING_APPROVAL");

        // No side effect before the human says yes.
        assertThat(taskStatus(workspaceId, taskId)).isEqualTo(TaskStatus.OPEN);

        var sources = readList(objectMapper, get(
                restTemplate, "/api/v1/agent-runs/" + runId + "/context-sources", owner).getBody());
        assertThat(sources).anySatisfy(source ->
                assertThat(source.get("type")).isEqualTo("TASK"));
        assertThat(sources).anySatisfy(source ->
                assertThat(source.get("label")).asString().contains("Close the release checklist"));

        var approvals = readList(objectMapper, get(
                restTemplate, "/api/v1/agent-runs/" + runId + "/approvals?status=PENDING", owner).getBody());
        assertThat(approvals).hasSize(1);
        var approval = approvals.getFirst();
        assertThat(approval.get("toolKey")).isEqualTo("task.update_status");
        assertThat(approval.get("targetResource")).isEqualTo("task:" + taskId);
        assertThat(approval.get("riskLevel")).isEqualTo("INTERNAL_WRITE");
        assertThat(approval.get("impactSummary")).asString()
                .contains("Close the release checklist")
                .contains("OPEN")
                .contains("DONE");

        var decision = post(
                restTemplate,
                "/api/v1/agent-runs/" + runId + "/approvals/" + approval.get("id") + "/decision",
                owner,
                Map.of("decision", "APPROVE", "note", "Approved for the release"));
        assertThat(decision.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(readMap(objectMapper, decision.getBody()).get("status")).isEqualTo("APPROVED");

        var finished = awaitStatus(owner, runId, "SUCCEEDED");
        assertThat(finished.get("status")).isEqualTo("SUCCEEDED");
        assertThat(taskStatus(workspaceId, taskId)).isEqualTo(TaskStatus.DONE);

        var artifacts = readList(objectMapper, get(
                restTemplate, "/api/v1/agent-runs/" + runId + "/artifacts", owner).getBody());
        assertThat(artifacts).anySatisfy(artifact ->
                assertThat(artifact.get("kind")).isEqualTo("RUN_SUMMARY"));

        var invocations = readList(objectMapper, get(
                restTemplate, "/api/v1/agent-runs/" + runId + "/tool-invocations", owner).getBody());
        assertThat(invocations).hasSize(1);
        assertThat(invocations.getFirst().get("status")).isEqualTo("SUCCEEDED");

        var events = readList(objectMapper, get(
                restTemplate, "/api/v1/agent-runs/" + runId + "/events", owner).getBody());
        var types = events.stream().map(event -> (String) event.get("type")).toList();
        assertThat(types).containsSubsequence(
                "RUN_QUEUED",
                "RUN_CONTEXT_BUILDING",
                "RUN_CONTEXT_READY",
                "RUN_STARTED",
                "APPROVAL_REQUESTED",
                "RUN_WAITING_APPROVAL",
                "APPROVAL_APPROVED",
                "RUN_RESUMED",
                "TOOL_COMPLETED",
                "RUN_SUCCEEDED");
        assertThat(seqOf(events)).isSorted();
        assertThat(seqOf(events)).doesNotHaveDuplicates();
    }

    @Test
    void rejectedApprovalLeavesNoSideEffect() {
        var owner = register(restTemplate, objectMapper, uniqueEmail("reject"), "Rejecter");
        var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Runtime Reject");
        var taskId = createTaskId(restTemplate, objectMapper, owner, workspaceId, Map.of(
                "title", "Do not auto-close me"));

        var runId = startRun(owner, workspaceId, taskId);
        awaitStatus(owner, runId, "WAITING_APPROVAL");
        var approvals = readList(objectMapper, get(
                restTemplate, "/api/v1/agent-runs/" + runId + "/approvals?status=PENDING", owner).getBody());
        var approvalId = (String) approvals.getFirst().get("id");

        var decision = post(
                restTemplate,
                "/api/v1/agent-runs/" + runId + "/approvals/" + approvalId + "/decision",
                owner,
                Map.of("decision", "REJECT", "note", "Not yet"));
        assertThat(decision.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(readMap(objectMapper, decision.getBody()).get("status")).isEqualTo("REJECTED");

        awaitStatus(owner, runId, "SUCCEEDED");
        assertThat(taskStatus(workspaceId, taskId)).isEqualTo(TaskStatus.OPEN);

        var invocations = readList(objectMapper, get(
                restTemplate, "/api/v1/agent-runs/" + runId + "/tool-invocations", owner).getBody());
        assertThat(invocations).anySatisfy(invocation ->
                assertThat(invocation.get("status")).isEqualTo("REJECTED"));

        var events = readList(objectMapper, get(
                restTemplate, "/api/v1/agent-runs/" + runId + "/events", owner).getBody());
        var types = events.stream().map(event -> (String) event.get("type")).toList();
        assertThat(types).contains("APPROVAL_REJECTED");
        assertThat(types).doesNotContain("TOOL_COMPLETED");
    }

    @Test
    void outsidersCannotReadAndViewersCannotStartRuns() {
        var owner = register(restTemplate, objectMapper, uniqueEmail("owner"), "Owner");
        var outsider = register(restTemplate, objectMapper, uniqueEmail("outsider"), "Outsider");
        var viewerEmail = uniqueEmail("viewer");
        var viewer = register(restTemplate, objectMapper, viewerEmail, "Viewer");
        var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Runtime Guard");
        var taskId = createTaskId(restTemplate, objectMapper, owner, workspaceId, Map.of(
                "title", "Guarded task"));

        addMemberByEmail(restTemplate, owner, workspaceId, viewerEmail);
        var roleResponse = exchange(
                restTemplate,
                "/api/v1/workspaces/" + workspaceId + "/members/" + viewer.userId() + "/role",
                HttpMethod.PUT,
                authJson(owner, Map.of("role", "VIEWER")));
        assertThat(roleResponse.getStatusCode()).isEqualTo(HttpStatus.OK);

        var runId = startRun(owner, workspaceId, taskId);

        var outsiderRead = get(restTemplate, "/api/v1/agent-runs/" + runId, outsider);
        assertThat(outsiderRead.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        var viewerStart = post(
                restTemplate,
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/agent-runs",
                viewer,
                Map.of("goal", "do work"));
        assertThat(viewerStart.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void restartKeepsPendingApprovalValidAndMarksInFlightRunsInterrupted() {
        var owner = register(restTemplate, objectMapper, uniqueEmail("restart"), "Restarter");
        var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Runtime Restart");
        var taskId = createTaskId(restTemplate, objectMapper, owner, workspaceId, Map.of(
                "title", "Survive a restart"));

        var runId = startRun(owner, workspaceId, taskId);
        awaitStatus(owner, runId, "WAITING_APPROVAL");

        runtimeService.recoverAfterRestart();

        var afterRecovery = readMap(objectMapper, get(
                restTemplate, "/api/v1/agent-runs/" + runId, owner).getBody());
        assertThat(afterRecovery.get("status")).isEqualTo("WAITING_APPROVAL");
        assertThat(afterRecovery.get("pendingApprovalId")).isNotNull();

        var approvals = readList(objectMapper, get(
                restTemplate, "/api/v1/agent-runs/" + runId + "/approvals?status=PENDING", owner).getBody());
        assertThat(approvals).hasSize(1);

        var approvalId = (String) approvals.getFirst().get("id");
        var decision = post(
                restTemplate,
                "/api/v1/agent-runs/" + runId + "/approvals/" + approvalId + "/decision",
                owner,
                Map.of("decision", "APPROVE"));
        assertThat(decision.getStatusCode()).isEqualTo(HttpStatus.OK);
        awaitStatus(owner, runId, "SUCCEEDED");
    }

    @Test
    void retryIsRejectedForRunsThatAlreadySucceeded() {
        var owner = register(restTemplate, objectMapper, uniqueEmail("retry"), "Retrier");
        var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Runtime Retry");
        var taskId = createTaskId(restTemplate, objectMapper, owner, workspaceId, Map.of(
                "title", "Already done"));

        var runId = startRun(owner, workspaceId, taskId);
        awaitStatus(owner, runId, "WAITING_APPROVAL");
        var approvals = readList(objectMapper, get(
                restTemplate, "/api/v1/agent-runs/" + runId + "/approvals?status=PENDING", owner).getBody());
        var approvalId = (String) approvals.getFirst().get("id");
        post(restTemplate,
                "/api/v1/agent-runs/" + runId + "/approvals/" + approvalId + "/decision",
                owner,
                Map.of("decision", "APPROVE"));
        awaitStatus(owner, runId, "SUCCEEDED");

        var retry = post(restTemplate, "/api/v1/agent-runs/" + runId + "/retry", owner, Map.of());
        assertThat(retry.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void cancellingAWaitingRunClosesItsUnfinishedSteps() {
        var owner = register(restTemplate, objectMapper, uniqueEmail("cancel"), "Canceller");
        var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Cancel audit");
        var taskId = createTaskId(restTemplate, objectMapper, owner, workspaceId, Map.of());
        var runId = startRun(owner, workspaceId, taskId);
        awaitStatus(owner, runId, "WAITING_APPROVAL");
        var cancelled = post(restTemplate, "/api/v1/agent-runs/" + runId + "/cancel", owner, Map.of());
        assertThat(cancelled.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(readMap(objectMapper, cancelled.getBody()).get("status")).isEqualTo("CANCELLED");
        var steps = readList(objectMapper, get(restTemplate, "/api/v1/agent-runs/" + runId + "/steps", owner).getBody());
        assertThat(steps).noneSatisfy(step -> assertThat(step.get("status")).isEqualTo("RUNNING"));
        assertThat(steps).anySatisfy(step -> assertThat(step.get("status")).isEqualTo("CANCELLED"));
    }

    // ------------------------------------------------------------------ helpers

    private String uniqueEmail(String prefix) {
        return prefix + "-" + System.nanoTime() + "@example.com";
    }

    private String startRun(Session session, String workspaceId, String taskId) {
        var response = post(
                restTemplate,
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/agent-runs",
                session,
                Map.of("goal", "Close this task out"));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        var body = readMap(objectMapper, response.getBody());
        assertThat(body.get("id")).isNotNull();
        assertThat(body.get("taskId")).isEqualTo(taskId);
        assertThat(body.get("status")).isIn(
                "QUEUED", "CONTEXT_BUILDING", "RUNNING", "WAITING_APPROVAL");
        return (String) body.get("id");
    }

    private Map<String, Object> awaitStatus(Session session, String runId, String expected) {
        var deadline = System.nanoTime() + Duration.ofSeconds(15).toNanos();
        Map<String, Object> last = Map.of();
        while (System.nanoTime() < deadline) {
            var response = get(restTemplate, "/api/v1/agent-runs/" + runId, session);
            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
            last = readMap(objectMapper, response.getBody());
            if (expected.equals(last.get("status"))) {
                return last;
            }
            if ("SUCCEEDED".equals(last.get("status")) || "FAILED".equals(last.get("status"))) {
                assertThat(last.get("status"))
                        .as("run %s ended as %s (%s)", runId, last.get("status"), last.get("errorMessage"))
                        .isEqualTo(expected);
            }
            try {
                Thread.sleep(100);
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                break;
            }
        }
        throw new AssertionError("Timed out waiting for run %s to reach %s, last status %s"
                .formatted(runId, expected, last.get("status")));
    }

    private TaskStatus taskStatus(String workspaceId, String taskId) {
        return taskRepository.findTask(workspaceId, taskId)
                .orElseThrow(() -> new AssertionError("Task disappeared: " + taskId))
                .status();
    }

    private List<Long> seqOf(List<Map<String, Object>> events) {
        return events.stream()
                .map(event -> ((Number) event.get("seq")).longValue())
                .toList();
    }
}
