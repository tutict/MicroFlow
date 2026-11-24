package com.microflow.agent.runtime;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.microflow.agent.runtime.infrastructure.persistence.JdbcAgentRuntimeRepository;
import com.microflow.task.domain.model.TaskStatus;
import com.microflow.task.infrastructure.persistence.JdbcTaskRepository;
import com.microflow.testing.MicroFlowApiTestSupport;
import com.microflow.testing.QuarkusRestTemplate;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.QuarkusTestProfile;
import io.quarkus.test.junit.TestProfile;
import io.quarkus.test.common.http.TestHTTPResource;
import jakarta.inject.Inject;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.WebSocket;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionStage;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

@QuarkusTest
@TestProfile(AgentRuntimeBatchTests.Profile.class)
class AgentRuntimeBatchTests extends MicroFlowApiTestSupport {

    private static final Path DATABASE = database();
    private static final String PLAN = """
            {"turns":[
              {"text":"Start, draft, then finish.","toolCalls":[
                {"callId":"call_start","toolKey":"task.update_status","input":{"status":"IN_PROGRESS"}},
                {"callId":"call_draft","toolKey":"artifact.create","input":{"title":"Batch draft","content":"Approved work"}},
                {"callId":"call_finish","toolKey":"task.update_status","input":{"status":"DONE"}}
              ]},
              {"text":"The reviewed work is complete."}
            ]}
            """;

    public static class Profile implements QuarkusTestProfile {
        @Override
        public Map<String, String> getConfigOverrides() {
            return Map.of(
                    "microflow.database.path", DATABASE.toString(),
                    "microflow.agent.mock-delay", "PT0.01S",
                    "microflow.agent.mock-plan", PLAN,
                    "microflow.agent.runtime.max-steps", "2",
                    "microflow.agent.openclaw-state-dir", DATABASE.resolveSibling("no-provider-state").toString(),
                    "microflow.seed.demo-enabled", "false",
                    "microflow.jwt.secret", "runtime-batch-test-jwt-secret-with-entropy",
                    "microflow.crypto.secret", "ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA=");
        }
    }

    private final QuarkusRestTemplate http = new QuarkusRestTemplate();
    @Inject ObjectMapper json;
    @Inject JdbcTaskRepository tasks;
    @Inject JdbcAgentRuntimeRepository runtime;
    @TestHTTPResource("/") URI baseUri;

    @Test
    void channelFreeTaskUpdatesReachWorkspaceMembersButNotOutsiders() throws Exception {
        var owner = register(http, json, "broadcast-owner-" + System.nanoTime() + "@example.com", "Owner");
        var memberEmail = "broadcast-member-" + System.nanoTime() + "@example.com";
        var member = register(http, json, memberEmail, "Member");
        var outsider = register(http, json, "broadcast-other-" + System.nanoTime() + "@example.com", "Other");
        var workspaceId = createWorkspace(http, json, owner, "Member updates");
        addMemberByEmail(http, owner, workspaceId, memberEmail);
        var taskId = createTaskId(http, json, owner, workspaceId, Map.of());
        var memberEvents = new RunEventListener();
        var otherEvents = new RunEventListener();
        var memberSocket = openSocket(member, memberEvents);
        var otherSocket = openSocket(outsider, otherEvents);
        try {
            var response = post(http, "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/agent-runs",
                    owner, Map.of("goal", "Shared work"));
            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
            var runId = readMap(json, response.getBody()).get("id");
            var frame = memberEvents.messages.poll(3, TimeUnit.SECONDS);
            assertThat(frame).as("a connected workspace member needs task progress without a channel subscription")
                    .isNotNull();
            var event = readMap(json, frame);
            assertThat(event.get("type")).isEqualTo("AGENT_RUN_EVENT");
            assertThat(((Map<?, ?>) event.get("payload")).get("runId")).isEqualTo(runId);
            assertThat(otherEvents.messages.poll(200, TimeUnit.MILLISECONDS)).isNull();
        } finally {
            memberSocket.sendClose(WebSocket.NORMAL_CLOSURE, "done").join();
            otherSocket.sendClose(WebSocket.NORMAL_CLOSURE, "done").join();
        }
    }

    private WebSocket openSocket(Session session, RunEventListener listener) {
        var response = post(http, "/api/v1/auth/ws-ticket", session, Map.of());
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        var ticket = readMap(json, response.getBody()).get("ticket");
        return HttpClient.newHttpClient().newWebSocketBuilder().connectTimeout(Duration.ofSeconds(5))
                .buildAsync(URI.create("ws://" + baseUri.getAuthority() + "/ws?ticket=" + ticket), listener).join();
    }

    private static class RunEventListener implements WebSocket.Listener {
        final LinkedBlockingQueue<String> messages = new LinkedBlockingQueue<>();
        final StringBuilder partial = new StringBuilder();
        @Override public void onOpen(WebSocket socket) { socket.request(1); }
        @Override public CompletionStage<?> onText(WebSocket socket, CharSequence text, boolean last) {
            partial.append(text);
            if (last) { messages.add(partial.toString()); partial.setLength(0); }
            socket.request(1);
            return CompletableFuture.completedFuture(null);
        }
    }

    @Test
    void eachWriteInOneModelResponseNeedsItsOwnApprovalAndNoCallsAreLost() {
        var fixture = start("approve");
        awaitStatus(fixture, "WAITING_APPROVAL");
        assertThat(status(fixture)).isEqualTo(TaskStatus.OPEN);
        assertThat(list(fixture, "artifacts")).isEmpty();

        decidePending(fixture, "APPROVE");
        awaitStatus(fixture, "WAITING_APPROVAL");
        assertThat(status(fixture)).isEqualTo(TaskStatus.IN_PROGRESS);
        assertThat(list(fixture, "artifacts")).anySatisfy(artifact ->
                assertThat(artifact.get("title")).isEqualTo("Batch draft"));

        decidePending(fixture, "APPROVE");
        awaitStatus(fixture, "SUCCEEDED");
        assertThat(status(fixture)).isEqualTo(TaskStatus.DONE);
        assertThat(runtime.listInvocations(fixture.runId()))
                .extracting(invocation -> invocation.idempotencyKey())
                .containsExactly("call_start", "call_draft", "call_finish");
        assertThat(list(fixture, "artifacts").stream()
                .filter(artifact -> "Batch draft".equals(artifact.get("title"))))
                .hasSize(1);
    }

    @Test
    void rejectingTheFirstWriteStillOffersTheRemainingWriteWithoutRepeatingTheDraft() {
        var fixture = start("reject");
        awaitStatus(fixture, "WAITING_APPROVAL");
        decidePending(fixture, "REJECT");
        awaitStatus(fixture, "WAITING_APPROVAL");
        assertThat(status(fixture)).isEqualTo(TaskStatus.OPEN);
        assertThat(list(fixture, "artifacts")).hasSize(1);

        decidePending(fixture, "REJECT");
        awaitStatus(fixture, "SUCCEEDED");
        assertThat(status(fixture)).isEqualTo(TaskStatus.OPEN);
        assertThat(list(fixture, "tool-invocations"))
                .extracting(invocation -> invocation.get("status"))
                .containsExactly("REJECTED", "SUCCEEDED", "REJECTED");
    }

    @Test
    void modelStepsAndRunSnapshotsMakeTheWaitingStateInspectable() {
        var fixture = start("audit");
        awaitStatus(fixture, "WAITING_APPROVAL");
        assertThat(list(fixture, "steps")).anySatisfy(step -> {
            assertThat(step.get("kind")).isEqualTo("MODEL_TURN");
            assertThat(step.get("status")).isEqualTo("COMPLETED");
            assertThat(step.get("agentKey")).isNotNull();
        });
        var events = list(fixture, "events");
        var waitingEvent = events.stream()
                .filter(event -> "RUN_WAITING_APPROVAL".equals(event.get("type")))
                .findFirst().orElseThrow();
        var payload = (Map<?, ?>) waitingEvent.get("payload");
        assertThat(payload.get("run")).isInstanceOf(Map.class);
        var snapshot = (Map<?, ?>) payload.get("run");
        assertThat(snapshot.get("id")).isEqualTo(fixture.runId());
        assertThat(snapshot.get("taskId")).isEqualTo(fixture.taskId());
        assertThat(snapshot.get("status")).isEqualTo("WAITING_APPROVAL");
        assertThat(snapshot.get("pendingApprovalId")).isNotNull();
    }

    private Fixture start(String name) {
        var owner = register(http, json, name + "-" + System.nanoTime() + "@example.com", name);
        var workspaceId = createWorkspace(http, json, owner, "Batch " + name);
        var taskId = createTaskId(http, json, owner, workspaceId, Map.of("assigneeIsSelf", true));
        var response = post(http, "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/agent-runs",
                owner, Map.of("goal", "Review the batch"));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return new Fixture(owner, workspaceId, taskId, (String) readMap(json, response.getBody()).get("id"));
    }

    private void decidePending(Fixture fixture, String decision) {
        var pending = list(fixture, "approvals?status=PENDING");
        assertThat(pending).hasSize(1);
        var response = post(http, "/api/v1/agent-runs/" + fixture.runId() + "/approvals/"
                        + pending.getFirst().get("id") + "/decision",
                fixture.owner(), Map.of("decision", decision, "note", "Batch reviewed"));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private List<Map<String, Object>> list(Fixture fixture, String resource) {
        var response = get(http, "/api/v1/agent-runs/" + fixture.runId() + "/" + resource, fixture.owner());
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return readList(json, response.getBody());
    }

    private void awaitStatus(Fixture fixture, String expected) {
        var deadline = System.nanoTime() + Duration.ofSeconds(10).toNanos();
        while (System.nanoTime() < deadline) {
            var run = readMap(json, get(http, "/api/v1/agent-runs/" + fixture.runId(), fixture.owner()).getBody());
            if (expected.equals(run.get("status"))) return;
            if (List.of("SUCCEEDED", "FAILED", "CANCELLED").contains(run.get("status"))) {
                assertThat(run.get("status")).as("run ended: %s", run).isEqualTo(expected);
            }
            try {
                Thread.sleep(30);
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                throw new AssertionError(exception);
            }
        }
        throw new AssertionError("Run did not reach " + expected);
    }

    private TaskStatus status(Fixture fixture) {
        return tasks.findTask(fixture.workspaceId(), fixture.taskId()).orElseThrow().status();
    }

    private record Fixture(Session owner, String workspaceId, String taskId, String runId) { }

    private static Path database() {
        try {
            return Files.createTempDirectory("microflow-batch-").resolve("batch.db").toAbsolutePath();
        } catch (IOException exception) {
            throw new IllegalStateException(exception);
        }
    }
}
