package com.microflow.task;

import static org.assertj.core.api.Assertions.assertThat;

import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;
import com.microflow.testing.QuarkusRestTemplate;
import io.quarkus.test.common.http.TestHTTPResource;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.QuarkusTestProfile;
import io.quarkus.test.junit.TestProfile;
import jakarta.inject.Inject;
import java.io.IOException;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
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

@QuarkusTest
@TestProfile(TaskAgendaAndDecisionTests.Profile.class)
class TaskAgendaAndDecisionTests {

    private static final Path databasePath = createDatabasePath();

    public static class Profile implements QuarkusTestProfile {
        @Override
        public Map<String, String> getConfigOverrides() {
            return Map.of(
                    "microflow.database.path", databasePath.toAbsolutePath().toString(),
                    "microflow.agent.mock-delay", "PT0.05S",
                    "microflow.agent.openclaw-state-dir",
                            databasePath.resolveSibling("missing-qclaw-state").toString(),
                    "microflow.seed.demo-enabled", "false",
                    "microflow.jwt.secret", "agenda-test-jwt-secret-with-adequate-entropy",
                    "microflow.crypto.secret", "ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA="
            );
        }
    }

    private static Path createDatabasePath() {
        try {
            return Files.createTempDirectory("microflow-agenda-tests").resolve("agenda.db");
        } catch (IOException exception) {
            throw new IllegalStateException("Unable to create an agenda test database path", exception);
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

    @TestHTTPResource("/")
    private URI baseUri;

    private Session register(String email, String displayName) {
        var response = restTemplate.exchange(
                "/api/v1/auth/register",
                HttpMethod.POST,
                authJson(null, Map.of(
                        "email", email, "password", "Passw0rd!2345", "displayName", displayName)),
                String.class);
        assertThat(response.getStatusCode().toString()).isEqualTo(HttpStatus.OK.toString());
        var payload = readMap(response.getBody());
        return new Session(String.valueOf(payload.get("accessToken")), String.valueOf(payload.get("userId")));
    }

    private String createWorkspace(Session session, String name) {
        var response = restTemplate.exchange(
                "/api/v1/workspaces", HttpMethod.POST,
                authJson(session, Map.of("name", name)), String.class);
        assertThat(response.getStatusCode().toString()).isEqualTo(HttpStatus.OK.toString());
        return String.valueOf(readMap(response.getBody()).get("id"));
    }

    private void addMember(Session owner, String workspaceId, String email) {
        restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/members",
                HttpMethod.POST, authJson(owner, Map.of("email", email)), String.class);
    }

    private ResponseEntity<String> createTask(
            Session actor, String workspaceId, String title, Map<String, Object> extra
    ) {
        var body = new java.util.LinkedHashMap<String, Object>();
        body.put("title", title);
        body.putAll(extra);
        return restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks",
                HttpMethod.POST, authJson(actor, body), String.class);
    }

    private Map<String, Object> myWork(Session actor, String workspaceId) {
        var response = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/my-work",
                HttpMethod.GET, authJson(actor, null), String.class);
        assertThat(response.getStatusCode().toString()).isEqualTo(HttpStatus.OK.toString());
        return readMap(response.getBody());
    }

    private ResponseEntity<String> recordDecision(
            Session actor, String workspaceId, String taskId, Map<String, Object> body
    ) {
        return restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/decisions",
                HttpMethod.POST, authJson(actor, body), String.class);
    }

    @Test
    void agendaSplitsMyWorkIntoActionableBuckets() {
        var owner = register("agenda-owner@example.com", "Agenda Owner");
        var workspaceId = createWorkspace(owner, "Agenda Workspace");

        createTask(owner, workspaceId, "Assigned and open", Map.of("assigneeIsSelf", true));
        createTask(owner, workspaceId, "Unassigned and open", Map.of());
        var blockedTask = String.valueOf(readMap(createTask(
                owner, workspaceId, "Blocked task", Map.of("assigneeIsSelf", true)).getBody()).get("id"));
        restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + blockedTask + "/status",
                HttpMethod.PUT, authJson(owner, Map.of("status", "BLOCKED")), String.class);
        var doneTask = String.valueOf(readMap(createTask(
                owner, workspaceId, "Already done", Map.of("assigneeIsSelf", true)).getBody()).get("id"));
        restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + doneTask + "/status",
                HttpMethod.PUT, authJson(owner, Map.of("status", "DONE")), String.class);

        var agenda = myWork(owner, workspaceId);
        assertThat(((Number) agenda.get("actionableCount")).intValue()).isEqualTo(1);
        assertThat(((Number) agenda.get("blockedCount")).intValue()).isEqualTo(1);
        assertThat(((Number) agenda.get("awaitingOthersCount")).intValue()).isEqualTo(1);

        var actionableTitles = titles(agenda, "actionable");
        assertThat(actionableTitles).containsExactly("Assigned and open");
        assertThat(titles(agenda, "blocked")).containsExactly("Blocked task");
        assertThat(titles(agenda, "awaitingOthers")).containsExactly("Unassigned and open");
        assertThat(titles(agenda, "recentlyDone")).containsExactly("Already done");
    }

    @Test
    void agendaExcludesTasksThatOnlyConcernOtherPeople() {
        var owner = register("agenda-mine@example.com", "Agenda Mine");
        var other = register("agenda-other@example.com", "Agenda Other");
        var workspaceId = createWorkspace(owner, "Agenda Mine Workspace");
        addMember(owner, workspaceId, "agenda-other@example.com");

        createTask(owner, workspaceId, "Belongs to someone else",
                Map.of("assigneeUserId", other.userId()));

        var agenda = myWork(owner, workspaceId);
        assertThat(((Number) agenda.get("actionableCount")).intValue()).isEqualTo(0);
        assertThat(((Number) agenda.get("awaitingOthersCount")).intValue())
                .as("a task assigned to another member is not my work even if I created it")
                .isEqualTo(0);

        var otherAgenda = myWork(other, workspaceId);
        assertThat(((Number) otherAgenda.get("actionableCount")).intValue()).isEqualTo(1);
        assertThat(titles(otherAgenda, "actionable")).containsExactly("Belongs to someone else");
    }

    @Test
    void agendaIsEmptyForAFreshWorkspace() {
        var owner = register("agenda-empty@example.com", "Agenda Empty");
        var workspaceId = createWorkspace(owner, "Agenda Empty Workspace");

        var agenda = myWork(owner, workspaceId);
        assertThat(((Number) agenda.get("actionableCount")).intValue()).isEqualTo(0);
        assertThat(((Number) agenda.get("blockedCount")).intValue()).isEqualTo(0);
        assertThat(((Number) agenda.get("awaitingOthersCount")).intValue()).isEqualTo(0);
        assertThat(titles(agenda, "recentlyDone")).isEmpty();
    }

    @Test
    void tasksWithoutDueDateSortAfterTasksThatHaveOne() {
        var owner = register("agenda-order@example.com", "Agenda Order");
        var workspaceId = createWorkspace(owner, "Agenda Order Workspace");

        // An older task with no due date must not outrank a newer dated one.
        var undated = String.valueOf(readMap(createTask(
                owner, workspaceId, "Undated but urgent",
                Map.of("assigneeIsSelf", true)).getBody()).get("id"));
        var dated = String.valueOf(readMap(createTask(
                owner, workspaceId, "Dated and later",
                Map.of("assigneeIsSelf", true, "dueAt", "2099-01-01T00:00:00Z")).getBody()).get("id"));

        var agenda = myWork(owner, workspaceId);
        var order = titles(agenda, "actionable");
        assertThat(order).containsExactlyInAnyOrder("Undated but urgent", "Dated and later");
        assertThat(order)
                .as("a task without a due date must sort last, otherwise every "
                        + "undated item floats to the top of the agenda")
                .endsWith("Undated but urgent");
        assertThat(undated).isNotBlank();
        assertThat(dated).isNotBlank();
    }

    @Test
    void recentlyDoneIsCappedAtFive() {
        var owner = register("agenda-cap@example.com", "Agenda Cap");
        var workspaceId = createWorkspace(owner, "Agenda Cap Workspace");

        for (var index = 1; index <= 8; index++) {
            var taskId = String.valueOf(readMap(createTask(
                    owner, workspaceId, "Finished " + index,
                    Map.of("assigneeIsSelf", true)).getBody()).get("id"));
            restTemplate.exchange(
                    "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/status",
                    HttpMethod.PUT, authJson(owner, Map.of("status", "DONE")), String.class);
        }

        var agenda = myWork(owner, workspaceId);
        var done = titles(agenda, "recentlyDone");
        assertThat(done)
                .as("recentlyDone must stay a short digest, not the full history")
                .hasSize(5);
        assertThat(done).contains("Finished 8", "Finished 4");
        assertThat(done)
                .as("the newest completions must win the limited slots")
                .doesNotContain("Finished 1", "Finished 2", "Finished 3");
    }

    @Test
    void olderUnassignedWorkSurvivesABusyWorkspace() {
        var owner = register("agenda-window@example.com", "Agenda Window");
        var workspaceId = createWorkspace(owner, "Agenda Window Workspace");

        // My unassigned task goes in first so it is the oldest row in the workspace.
        createTask(owner, workspaceId, "My old unassigned task", Map.of());

        // Then a burst of tasks that are none of my business pushes it past the window.
        // These must be *newer* than mine, which they are: created after it above.
        for (var index = 1; index <= 60; index++) {
            createTask(owner, workspaceId, "Someone else's work " + index,
                    Map.of("assigneeIsSelf", true));
        }

        var agenda = myWork(owner, workspaceId);
        assertThat(titles(agenda, "awaitingOthers"))
                .as("an unassigned task I created must stay on my agenda even when "
                        + "the workspace is busier than the query limit")
                .contains("My old unassigned task");
    }

    @Test
    void nonMemberCannotReadMyWork() {
        var owner = register("agenda-guard@example.com", "Agenda Guard");
        var outsider = register("agenda-outsider@example.com", "Agenda Outsider");
        var workspaceId = createWorkspace(owner, "Agenda Guard Workspace");

        var response = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/my-work",
                HttpMethod.GET, authJson(outsider, null), String.class);
        assertThat(response.getStatusCode().toString()).isEqualTo(HttpStatus.FORBIDDEN.toString());
    }

    @Test
    void decisionTrailKeepsASequenceAndSupersedes() {
        var owner = register("decision-owner@example.com", "Decision Owner");
        var workspaceId = createWorkspace(owner, "Decision Workspace");
        var taskId = String.valueOf(readMap(createTask(
                owner, workspaceId, "Contested task", Map.of("assigneeIsSelf", true)).getBody()).get("id"));

        var first = recordDecision(owner, workspaceId, taskId, Map.of(
                "summary", "Ship with SQLite",
                "rationale", "Zero-ops deployment matters more than concurrency",
                "alternativesConsidered", "Postgres, in-memory only"));
        assertThat(first.getStatusCode().toString()).isEqualTo(HttpStatus.OK.toString());
        var firstPayload = readMap(first.getBody());
        assertThat(((Number) firstPayload.get("sequenceNo")).intValue()).isEqualTo(1);
        assertThat(firstPayload.get("decidedByDisplayName")).isEqualTo("Decision Owner");

        var second = recordDecision(owner, workspaceId, taskId, Map.of(
                "summary", "Switch to Postgres",
                "rationale", "Concurrent writes finally became a real requirement",
                "alternativesConsidered", "Keep SQLite",
                "supersedesDecisionId", firstPayload.get("id")));
        assertThat(second.getStatusCode().toString()).isEqualTo(HttpStatus.OK.toString());
        var secondPayload = readMap(second.getBody());
        assertThat(((Number) secondPayload.get("sequenceNo")).intValue()).isEqualTo(2);
        assertThat(secondPayload.get("supersedesDecisionId")).isEqualTo(firstPayload.get("id"));

        var history = readList(restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/decisions",
                HttpMethod.GET, authJson(owner, null), String.class).getBody());
        assertThat(history).hasSize(2);
        assertThat(history.get(0).get("summary")).isEqualTo("Switch to Postgres");
        assertThat(history.get(1).get("summary")).isEqualTo("Ship with SQLite");
        assertThat(history.get(1).get("alternativesConsidered")).isEqualTo("Postgres, in-memory only");
    }

    @Test
    void secondDecisionWithoutSupersedesIsRejected() {
        var owner = register("decision-dup@example.com", "Decision Dup");
        var workspaceId = createWorkspace(owner, "Decision Dup Workspace");
        var taskId = String.valueOf(readMap(createTask(
                owner, workspaceId, "Single decision task", Map.of("assigneeIsSelf", true)).getBody()).get("id"));

        recordDecision(owner, workspaceId, taskId, Map.of("summary", "First call"));

        var second = recordDecision(owner, workspaceId, taskId, Map.of("summary", "Silent override"));
        assertThat(second.getStatusCode().toString()).isEqualTo(HttpStatus.BAD_REQUEST.toString());
        assertThat(String.valueOf(readMap(second.getBody()).get("message")))
                .contains("supersedesDecisionId");
    }

    @Test
    void decisionCannotSupersedeADecisionOnAnotherTask() {
        var owner = register("decision-cross@example.com", "Decision Cross");
        var workspaceId = createWorkspace(owner, "Decision Cross Workspace");
        var firstTask = String.valueOf(readMap(createTask(
                owner, workspaceId, "First task", Map.of("assigneeIsSelf", true)).getBody()).get("id"));
        var secondTask = String.valueOf(readMap(createTask(
                owner, workspaceId, "Second task", Map.of("assigneeIsSelf", true)).getBody()).get("id"));

        var firstDecision = String.valueOf(readMap(recordDecision(
                owner, workspaceId, firstTask, Map.of("summary", "Belongs to first task")).getBody()).get("id"));

        var crossTask = recordDecision(owner, workspaceId, secondTask, Map.of(
                "summary", "Should not be allowed",
                "supersedesDecisionId", firstDecision));
        assertThat(crossTask.getStatusCode().toString()).isEqualTo(HttpStatus.BAD_REQUEST.toString());
    }

    @Test
    void blankDecisionSummaryIsRejected() {
        var owner = register("decision-blank@example.com", "Decision Blank");
        var workspaceId = createWorkspace(owner, "Decision Blank Workspace");
        var taskId = String.valueOf(readMap(createTask(
                owner, workspaceId, "Blank task", Map.of("assigneeIsSelf", true)).getBody()).get("id"));

        var blank = recordDecision(owner, workspaceId, taskId, Map.of("summary", "   "));
        assertThat(blank.getStatusCode().toString()).isEqualTo(HttpStatus.BAD_REQUEST.toString());
    }

    @Test
    void decisionWriteIsLimitedToTheAccountableCircle() {
        var owner = register("decision-owner2@example.com", "Decision Owner2");
        var stranger = register("decision-stranger@example.com", "Decision Stranger");
        var workspaceId = createWorkspace(owner, "Decision Stranger Workspace");
        addMember(owner, workspaceId, "decision-stranger@example.com");
        var taskId = String.valueOf(readMap(createTask(
                owner, workspaceId, "Owner task", Map.of()).getBody()).get("id"));

        var rejected = recordDecision(stranger, workspaceId, taskId, Map.of("summary", "Not mine to decide"));
        assertThat(rejected.getStatusCode().toString()).isEqualTo(HttpStatus.FORBIDDEN.toString());

        var readable = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/decisions",
                HttpMethod.GET, authJson(stranger, null), String.class);
        assertThat(readable.getStatusCode().toString()).isEqualTo(HttpStatus.OK.toString(),
                "any member may read the reasoning trail");
    }

    @Test
    void decisionsForUnknownTaskAreNotFound() {
        var owner = register("decision-missing@example.com", "Decision Missing");
        var workspaceId = createWorkspace(owner, "Decision Missing Workspace");

        var response = recordDecision(owner, workspaceId, "task_missing", Map.of("summary", "Ghost"));
        assertThat(response.getStatusCode().toString()).isEqualTo(HttpStatus.NOT_FOUND.toString());
    }

    private List<String> titles(Map<String, Object> agenda, String key) {
        var rows = readListFromObject(agenda.get(key));
        return rows.stream().map(row -> String.valueOf(row.get("title"))).toList();
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> readListFromObject(Object value) {
        return (List<Map<String, Object>>) value;
    }

    private HttpEntity<?> authJson(Session session, Map<String, Object> body) {
        var headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        if (session != null && session.token() != null && !session.token().isEmpty()) {
            headers.setBearerAuth(session.token());
        }
        return new HttpEntity<>(body, headers);
    }

    private Map<String, Object> readMap(String body) {
        try {
            return objectMapper.readValue(body, new TypeReference<Map<String, Object>>() {
            });
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to parse response: " + body, exception);
        }
    }

    private List<Map<String, Object>> readList(String body) {
        try {
            return objectMapper.readValue(body, new TypeReference<List<Map<String, Object>>>() {
            });
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to parse list response: " + body, exception);
        }
    }

    private record Session(String token, String userId) {
    }
}
