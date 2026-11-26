package com.microflow.workspace;

import static org.assertj.core.api.Assertions.assertThat;

import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;
import com.microflow.task.domain.model.TaskStatus;
import com.microflow.task.infrastructure.persistence.JdbcTaskRepository;
import com.microflow.testing.MicroFlowApiTestSupport;
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

/**
 * Covers the write paths that could silently do nothing: the last-owner guard, the
 * guarded status update, and decision sequencing. Each of these previously
 * reported success while writing nothing.
 */
@QuarkusTest
@TestProfile(ConcurrentWriteGuardTests.Profile.class)
class ConcurrentWriteGuardTests extends MicroFlowApiTestSupport {

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
                    "microflow.jwt.secret", "concurrent-test-jwt-secret-adequate-entropy",
                    "microflow.crypto.secret", "ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA="
            );
        }
    }

    private static Path createDatabasePath() {
        try {
            return Files.createTempDirectory("microflow-concurrent-tests").resolve("concurrent.db");
        } catch (IOException exception) {
            throw new IllegalStateException("Unable to create a test database path", exception);
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
        var payload = readMap(objectMapper, response.getBody());
        return new Session(String.valueOf(payload.get("accessToken")), String.valueOf(payload.get("userId")));
    }

    private String createWorkspace(Session session, String name) {
        var response = restTemplate.exchange(
                "/api/v1/workspaces", HttpMethod.POST,
                authJson(session, Map.of("name", name)), String.class);
        assertThat(response.getStatusCode().toString()).isEqualTo(HttpStatus.OK.toString());
        return String.valueOf(readMap(objectMapper, response.getBody()).get("id"));
    }

    private void addMember(Session owner, String workspaceId, String email) {
        restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/members",
                HttpMethod.POST, authJson(owner, Map.of("email", email)), String.class);
    }

    private ResponseEntity<String> changeRole(
            Session actor, String workspaceId, String targetUserId, String role
    ) {
        return restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/members/" + targetUserId + "/role",
                HttpMethod.PUT, authJson(actor, Map.of("role", role)), String.class);
    }

    @Test
    void secondOwnerDemotionIsRejectedOnceOnlyOneOwnerRemains() {
        var first = register("guard-first@example.com", "Guard First");
        var second = register("guard-second@example.com", "Guard Second");
        var workspaceId = createWorkspace(first, "Guard Workspace");
        addMember(first, workspaceId, "guard-second@example.com");
        assertThat(changeRole(first, workspaceId, second.userId(), "OWNER").getStatusCode().toString())
                .isEqualTo(HttpStatus.OK.toString());

        // Two owners exist, so demoting the second one must be allowed and must land.
        var demoteSecond = changeRole(second, workspaceId, second.userId(), "MAINTAINER");
        assertThat(demoteSecond.getStatusCode().toString())
                .as("self-demotion stays forbidden even with a co-owner present")
                .isEqualTo(HttpStatus.BAD_REQUEST.toString());

        var demoteByOther = changeRole(first, workspaceId, second.userId(), "MAINTAINER");
        assertThat(demoteByOther.getStatusCode().toString()).isEqualTo(HttpStatus.OK.toString());

        // Now only one owner is left; the remaining owner cannot be demoted by anyone.
        var lastAttempt = changeRole(first, workspaceId, first.userId(), "VIEWER");
        assertThat(lastAttempt.getStatusCode().toString()).isEqualTo(HttpStatus.BAD_REQUEST.toString());

        var members = readList(objectMapper, restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/members",
                HttpMethod.GET, authJson(first, null), String.class).getBody());
        var owners = members.stream()
                .filter(member -> "OWNER".equals(String.valueOf(member.get("role"))))
                .count();
        assertThat(owners)
                .as("the workspace must still have exactly one owner after every attempt")
                .isEqualTo(1);
    }

    @Test
    void guardedStatusUpdateReportsWhetherItActuallyMovedTheRow() {
        var owner = register("stale-owner@example.com", "Stale Owner");
        var workspaceId = createWorkspace(owner, "Stale Workspace");
        var taskId = String.valueOf(readMap(objectMapper, restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks",
                HttpMethod.POST, authJson(owner, Map.of("title", "Contended")),
                String.class).getBody()).get("id"));

        // A writer that read OPEN applies the transition it expected.
        assertThat(taskRepository.applyStatus(taskId, TaskStatus.OPEN, TaskStatus.IN_PROGRESS))
                .as("the first writer holding the expected status must win")
                .isTrue();

        // A second writer that still believes the task is OPEN must be told it lost,
        // otherwise it records an activity for a transition that never happened.
        assertThat(taskRepository.applyStatus(taskId, TaskStatus.OPEN, TaskStatus.IN_PROGRESS))
                .as("a stale writer must be told the row already moved")
                .isFalse();

        var stored = taskRepository.findTask(workspaceId, taskId).orElseThrow();
        assertThat(stored.status())
                .as("the row must hold exactly one transition")
                .isEqualTo(TaskStatus.IN_PROGRESS);
    }

    @Test
    void decisionsRemainOrderedAcrossManyAppends() {
        var owner = register("order-owner@example.com", "Order Owner");
        var workspaceId = createWorkspace(owner, "Order Workspace");
        var taskId = String.valueOf(readMap(objectMapper, restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks",
                HttpMethod.POST, authJson(owner, Map.of("title", "Ordered")),
                String.class).getBody()).get("id"));

        String previousId = null;
        for (var index = 1; index <= 12; index++) {
            var body = new java.util.LinkedHashMap<String, Object>();
            body.put("summary", "Decision " + index);
            if (previousId != null) {
                body.put("supersedesDecisionId", previousId);
            }
            var response = restTemplate.exchange(
                    "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/decisions",
                    HttpMethod.POST, authJson(owner, body), String.class);
            assertThat(response.getStatusCode().toString())
                    .as("decision " + index + " must be accepted")
                    .isEqualTo(HttpStatus.OK.toString());
            var payload = readMap(objectMapper, response.getBody());
            assertThat(((Number) payload.get("sequenceNo")).intValue())
                    .as("sequence numbers must be dense and increasing")
                    .isEqualTo(index);
            previousId = String.valueOf(payload.get("id"));
        }

        var history = readList(objectMapper, restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/decisions",
                HttpMethod.GET, authJson(owner, null), String.class).getBody());
        assertThat(history).hasSize(12);
        assertThat(history.get(0).get("summary")).isEqualTo("Decision 12");
        assertThat(history.get(11).get("summary")).isEqualTo("Decision 1");
    }

    @Test
    void taskCitingAnotherWorkspacesMessageIsRejected() {
        var owner = register("origin-owner@example.com", "Origin Owner");
        var stranger = register("origin-stranger@example.com", "Origin Stranger");
        var mine = createWorkspace(owner, "Origin Mine");
        var theirs = createWorkspace(stranger, "Origin Theirs");

        var theirChannel = String.valueOf(readList(objectMapper, restTemplate.exchange(
                "/api/v1/workspaces/" + theirs + "/channels",
                HttpMethod.GET, authJson(stranger, null), String.class).getBody())
                .get(0).get("id"));

        var foreignMessage = String.valueOf(readMap(objectMapper, restTemplate.exchange(
                "/api/v1/channels/" + theirChannel + "/messages",
                HttpMethod.POST,
                authJson(stranger, Map.of("workspaceId", theirs, "content", "secret")),
                String.class).getBody()).get("id"));

        var response = restTemplate.exchange(
                "/api/v1/workspaces/" + mine + "/tasks",
                HttpMethod.POST,
                authJson(owner, Map.of("title", "Cites foreign message", "originMessageId", foreignMessage)),
                String.class);
        assertThat(response.getStatusCode().toString())
                .as("a message from another workspace must not be citable")
                .isEqualTo(HttpStatus.NOT_FOUND.toString());
    }
}
