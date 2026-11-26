package com.microflow.agent.runtime;

import static org.assertj.core.api.Assertions.assertThat;

import tools.jackson.databind.ObjectMapper;
import com.microflow.agent.runtime.domain.model.AgentRunSession;
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
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

@QuarkusTest
@TestProfile(TaskRunAgendaTests.Profile.class)
class TaskRunAgendaTests extends MicroFlowApiTestSupport {
    private static final Path DATABASE = database();

    public static class Profile implements QuarkusTestProfile {
        @Override
        public Map<String, String> getConfigOverrides() {
            return Map.of(
                    "microflow.database.path", DATABASE.toString(),
                    "microflow.agent.openclaw-state-dir", DATABASE.resolveSibling("no-provider-state").toString(),
                    "microflow.seed.demo-enabled", "false",
                    "microflow.jwt.secret", "task-run-agenda-test-jwt-secret-with-entropy",
                    "microflow.crypto.secret", "ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA=");
        }
    }

    private final QuarkusRestTemplate http = new QuarkusRestTemplate();
    @Inject ObjectMapper json;
    @Inject JdbcAgentRuntimeRepository runtime;

    @Test
    void activeRunsSeparateRunningAndApprovalTasksWithoutDuplicatingTheQueue() {
        var owner = owner();
        var workspaceId = createWorkspace(http, json, owner, "Live queue");
        var running = task(owner, workspaceId, "Running", "IN_PROGRESS");
        var waiting = task(owner, workspaceId, "Review", "OPEN");
        var blocked = task(owner, workspaceId, "Blocked", "BLOCKED");
        insertRun(owner, workspaceId, running, AgentRunStatus.QUEUED, Instant.now().toString());
        insertRun(owner, workspaceId, waiting, AgentRunStatus.WAITING_APPROVAL, Instant.now().toString());

        var agenda = agenda(owner, workspaceId);
        assertThat(ids(agenda, "running")).containsExactly(running);
        assertThat(ids(agenda, "waitingApproval")).containsExactly(waiting);
        assertThat(ids(agenda, "blocked")).containsExactly(blocked);
        assertThat(ids(agenda, "actionable")).isEmpty();
        assertThat(agenda.get("runningCount")).isEqualTo(1);
        assertThat(agenda.get("waitingApprovalCount")).isEqualTo(1);
    }

    @Test
    void approvalWinsOverAnotherActiveRunWhileCompletedTasksStayInHistory() {
        var owner = owner();
        var workspaceId = createWorkspace(http, json, owner, "Queue precedence");
        var waiting = task(owner, workspaceId, "Needs a review", "BLOCKED");
        var done = task(owner, workspaceId, "Already completed", "DONE");
        insertRun(owner, workspaceId, waiting, AgentRunStatus.WAITING_APPROVAL, "2020-01-01T00:00:00Z");
        insertRun(owner, workspaceId, waiting, AgentRunStatus.RUNNING, Instant.now().toString());
        insertRun(owner, workspaceId, done, AgentRunStatus.RUNNING, Instant.now().toString());

        var agenda = agenda(owner, workspaceId);
        assertThat(ids(agenda, "waitingApproval")).containsExactly(waiting);
        assertThat(ids(agenda, "running")).isEmpty();
        assertThat(ids(agenda, "blocked")).isEmpty();
        assertThat(ids(agenda, "recentlyDone")).containsExactly(done);
    }

    @Test
    void aRunInAnotherWorkspaceCannotMoveTheCallersTaskIntoApproval() {
        var owner = owner();
        var visible = createWorkspace(http, json, owner, "Visible queue");
        var unrelated = createWorkspace(http, json, owner, "Other queue");
        var taskId = task(owner, visible, "My task", "OPEN");
        insertRun(owner, unrelated, taskId, AgentRunStatus.WAITING_APPROVAL, Instant.now().toString());
        var agenda = agenda(owner, visible);
        assertThat(ids(agenda, "actionable")).containsExactly(taskId);
        assertThat(ids(agenda, "waitingApproval")).isEmpty();
        assertThat(ids(agenda, "running")).isEmpty();

        var outsider = owner();
        assertThat(get(http, "/api/v1/workspaces/" + visible + "/my-work", outsider).getStatusCode())
                .isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void anOldApprovalRunRemainsVisibleWhenRecentHistoryExceedsTheListWindow() {
        var owner = owner();
        var workspaceId = createWorkspace(http, json, owner, "Busy run history");
        var taskId = task(owner, workspaceId, "Review old work", "OPEN");
        var waitingId = insertRun(owner, workspaceId, taskId, AgentRunStatus.WAITING_APPROVAL,
                "2020-01-01T00:00:00Z");
        for (var index = 0; index < 55; index++) {
            insertRun(owner, workspaceId, taskId, AgentRunStatus.SUCCEEDED, Instant.now().toString());
        }
        var runs = readList(json, get(http, "/api/v1/workspaces/" + workspaceId + "/agent-runs",
                owner).getBody());
        assertThat(runs.getFirst().get("id")).isEqualTo(waitingId);
        assertThat(runs).hasSize(50);
    }

    @Test
    void activeRunPagingCoversMoreThanTheDefaultWindowWithoutRepeatingRows() {
        var owner = owner();
        var workspaceId = createWorkspace(http, json, owner, "Active pages");
        var taskId = task(owner, workspaceId, "Many reviews", "OPEN");
        var expected = new java.util.HashSet<String>();
        for (var index = 0; index < 75; index++) {
            expected.add(insertRun(owner, workspaceId, taskId, AgentRunStatus.WAITING_APPROVAL, Instant.now().toString()));
        }
        insertRun(owner, workspaceId, taskId, AgentRunStatus.SUCCEEDED, Instant.now().toString());
        var actual = new java.util.HashSet<String>();
        String after = null;
        for (var page = 0; page < 10; page++) {
            var path = "/api/v1/workspaces/" + workspaceId + "/agent-runs?activeOnly=true&limit=20"
                    + (after == null ? "" : "&afterId=" + after);
            var rows = readList(json, get(http, path, owner).getBody());
            if (rows.isEmpty()) break;
            for (var row : rows) {
                assertThat(row.get("status")).isEqualTo("WAITING_APPROVAL");
                assertThat(actual.add((String) row.get("id"))).as("paging must advance").isTrue();
            }
            after = (String) rows.getLast().get("id");
        }
        assertThat(actual).containsExactlyInAnyOrderElementsOf(expected);
    }

    private Session owner() {
        return register(http, json, "agenda-" + System.nanoTime() + "@example.com", "Owner");
    }

    private String task(Session owner, String workspaceId, String title, String status) {
        return createTaskId(http, json, owner, workspaceId,
                Map.of("title", title, "status", status, "assigneeIsSelf", true));
    }

    private String insertRun(Session owner, String workspaceId, String taskId, AgentRunStatus status, String at) {
        var id = "run_" + UUID.randomUUID();
        runtime.insertSession(new AgentRunSession(id, workspaceId, taskId, null, null, owner.userId(),
                "assistant", "TASK", status, "Advance the task", null, null, "NONE", null,
                0, 0, 0, at, null, null, at));
        return id;
    }

    private Map<String, Object> agenda(Session owner, String workspaceId) {
        var response = get(http, "/api/v1/workspaces/" + workspaceId + "/my-work", owner);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return readMap(json, response.getBody());
    }

    private List<String> ids(Map<String, Object> agenda, String lane) {
        assertThat(agenda.get(lane)).as("queue lane %s", lane).isInstanceOf(List.class);
        return ((List<?>) agenda.get(lane)).stream().map(item -> (String) ((Map<?, ?>) item).get("id")).toList();
    }

    private static Path database() {
        try {
            return Files.createTempDirectory("microflow-run-agenda-").resolve("agenda.db").toAbsolutePath();
        } catch (IOException exception) {
            throw new IllegalStateException(exception);
        }
    }
}
