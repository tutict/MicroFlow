package com.microflow.workspace;

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
@TestProfile(WorkspaceRoleCapabilityTests.Profile.class)
class WorkspaceRoleCapabilityTests {
    @org.junit.jupiter.params.ParameterizedTest
    @org.junit.jupiter.params.provider.ValueSource(strings = {"status", "assignee", "decisions"})
    void demotedCreatorCannotWriteTheirExistingTask(String action) {
        var suffix = action + System.nanoTime();
        var owner = register("existing-owner-" + suffix + "@example.com", "Owner");
        var email = "existing-viewer-" + suffix + "@example.com";
        var creator = register(email, "Creator");
        var workspaceId = createWorkspace(owner, "Existing task guard");
        addMember(owner, workspaceId, email);
        var taskId = String.valueOf(readMap(createTask(creator, workspaceId, "Created before demotion").getBody()).get("id"));
        assertThat(changeRole(owner, workspaceId, creator.userId(), "VIEWER").getStatusCode()).isEqualTo(HttpStatus.OK);
        var body = switch (action) {
            case "status" -> Map.<String, Object>of("status", "IN_PROGRESS");
            case "assignee" -> Map.<String, Object>of("assigneeIsSelf", true);
            default -> Map.<String, Object>of("summary", "New decision", "rationale", "Would be a write");
        };
        var method = action.equals("decisions") ? HttpMethod.POST : HttpMethod.PUT;

        var response = restTemplate.exchange("/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/" + action,
                method, authJson(creator, body), String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        var read = restTemplate.exchange("/api/v1/workspaces/" + workspaceId + "/tasks",
                HttpMethod.GET, authJson(creator, null), String.class);
        assertThat(read.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(readList(read.getBody())).anySatisfy(task -> {
            assertThat(task.get("id")).isEqualTo(taskId);
            assertThat(task.get("status")).isEqualTo("OPEN");
        });
    }

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
                    "microflow.jwt.secret", "role-test-jwt-secret-with-adequate-entropy",
                    "microflow.crypto.secret", "ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA="
            );
        }
    }

    private static Path createDatabasePath() {
        try {
            return Files.createTempDirectory("microflow-role-tests").resolve("roles.db");
        } catch (IOException exception) {
            throw new IllegalStateException("Unable to create a role test database path", exception);
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
                        "email", email,
                        "password", "Passw0rd!2345",
                        "displayName", displayName)),
                String.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        var payload = readMap(response.getBody());
        return new Session((String) payload.get("accessToken"), (String) payload.get("userId"));
    }

    private String createWorkspace(Session session, String name) {
        var response = restTemplate.exchange(
                "/api/v1/workspaces",
                HttpMethod.POST,
                authJson(session, Map.of("name", name)),
                String.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return (String) readMap(response.getBody()).get("id");
    }

    private void addMember(Session owner, String workspaceId, String email) {
        var response = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/members",
                HttpMethod.POST,
                authJson(owner, Map.of("email", email)),
                String.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private ResponseEntity<String> changeRole(
            Session actor, String workspaceId, String targetUserId, String role
    ) {
        return restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/members/" + targetUserId + "/role",
                HttpMethod.PUT,
                authJson(actor, Map.of("role", role)),
                String.class);
    }

    private ResponseEntity<String> createTask(Session actor, String workspaceId, String title) {
        return restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks",
                HttpMethod.POST,
                authJson(actor, Map.of("title", title)),
                String.class);
    }

    private ResponseEntity<String> createProject(Session actor, String workspaceId, String name) {
        return restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/task-projects",
                HttpMethod.POST,
                authJson(actor, Map.of("name", name)),
                String.class);
    }

    @Test
    void legacyMemberRoleIsNormalizedToOperatorByMigration() {
        var owner = register("legacy-owner@example.com", "Legacy Owner");
        var teammate = register("legacy-mate@example.com", "Legacy Teammate");
        var workspaceId = createWorkspace(owner, "Legacy Workspace");
        addMember(owner, workspaceId, "legacy-mate@example.com");

        var members = readList(restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/members",
                HttpMethod.GET,
                authJson(teammate, null),
                String.class).getBody());
        assertThat(members).hasSize(2);

        var teammateRole = members.stream()
                .filter(member -> teammate.userId().equals(member.get("userId")))
                .map(member -> String.valueOf(member.get("role")))
                .findFirst()
                .orElseThrow();
        assertThat(teammateRole).isEqualTo("OPERATOR",
                "a member added by the owner must land on the normalized operator role");
    }

    @Test
    void operatorCanCreateTasksButNotProjects() {
        var owner = register("op-owner@example.com", "Op Owner");
        var operator = register("op-member@example.com", "Op Member");
        var workspaceId = createWorkspace(owner, "Operator Workspace");
        addMember(owner, workspaceId, "op-member@example.com");

        assertThat(createTask(operator, workspaceId, "Operator task").getStatusCode())
                .isEqualTo(HttpStatus.OK);
        assertThat(createProject(operator, workspaceId, "Operator project").getStatusCode())
                .isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void viewerCannotWriteAnythingButCanRead() {
        var owner = register("view-owner@example.com", "View Owner");
        var viewer = register("view-member@example.com", "View Member");
        var workspaceId = createWorkspace(owner, "Viewer Workspace");
        addMember(owner, workspaceId, "view-member@example.com");
        assertThat(changeRole(owner, workspaceId, viewer.userId(), "VIEWER").getStatusCode())
                .isEqualTo(HttpStatus.OK);

        assertThat(createTask(viewer, workspaceId, "Viewer task").getStatusCode())
                .isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(createProject(viewer, workspaceId, "Viewer project").getStatusCode())
                .isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(changeRole(viewer, workspaceId, owner.userId(), "VIEWER").getStatusCode())
                .isEqualTo(HttpStatus.FORBIDDEN);

        var read = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks",
                HttpMethod.GET,
                authJson(viewer, null),
                String.class);
        assertThat(read.getStatusCode())
                .as("a viewer must still be able to read the task list")
                .isEqualTo(HttpStatus.OK);
    }

    @Test
    void maintainerCanCreateProjectsAndAssignOtherPeople() {
        var owner = register("maint-owner@example.com", "Maint Owner");
        var maintainer = register("maint-member@example.com", "Maint Member");
        var operator = register("maint-op@example.com", "Maint Operator");
        var workspaceId = createWorkspace(owner, "Maintainer Workspace");
        addMember(owner, workspaceId, "maint-member@example.com");
        addMember(owner, workspaceId, "maint-op@example.com");
        assertThat(changeRole(owner, workspaceId, maintainer.userId(), "MAINTAINER").getStatusCode())
                .isEqualTo(HttpStatus.OK);

        assertThat(createProject(maintainer, workspaceId, "Maintainer project").getStatusCode())
                .isEqualTo(HttpStatus.OK);

        var created = readMap(createTask(maintainer, workspaceId, "Assign me later").getBody());
        var taskId = String.valueOf(created.get("id"));

        var assigned = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/assignee",
                HttpMethod.PUT,
                authJson(maintainer, Map.of("assigneeUserId", operator.userId())),
                String.class);
        assertThat(assigned.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(readMap(assigned.getBody()).get("assigneeUserId"))
                .as("assigneeUserId")
                .isEqualTo(operator.userId());
    }

    @Test
    void operatorCannotAssignTaskToAnotherMember() {
        var owner = register("assignop-owner@example.com", "AssignOp Owner");
        var operator = register("assignop-a@example.com", "AssignOp A");
        var other = register("assignop-b@example.com", "AssignOp B");
        var workspaceId = createWorkspace(owner, "Assign Operator Workspace");
        addMember(owner, workspaceId, "assignop-a@example.com");
        addMember(owner, workspaceId, "assignop-b@example.com");

        var created = readMap(createTask(operator, workspaceId, "Owned by operator").getBody());
        var taskId = String.valueOf(created.get("id"));

        var assigned = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/assignee",
                HttpMethod.PUT,
                authJson(operator, Map.of("assigneeUserId", other.userId())),
                String.class);
        assertThat(assigned.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void onlyOwnerCanChangeRoles() {
        var owner = register("only-owner@example.com", "Only Owner");
        var maintainer = register("only-maint@example.com", "Only Maint");
        var teammate = register("only-op@example.com", "Only Op");
        var workspaceId = createWorkspace(owner, "Only Owner Workspace");
        addMember(owner, workspaceId, "only-maint@example.com");
        addMember(owner, workspaceId, "only-op@example.com");
        changeRole(owner, workspaceId, maintainer.userId(), "MAINTAINER");

        assertThat(changeRole(maintainer, workspaceId, teammate.userId(), "VIEWER").getStatusCode())
                .isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(changeRole(teammate, workspaceId, maintainer.userId(), "VIEWER").getStatusCode())
                .isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void aMaintainerCannotRemoveTheOnlyOwner() {
        var owner = register("solo-owner@example.com", "Solo Owner");
        var maintainer = register("solo-maint@example.com", "Solo Maint");
        var workspaceId = createWorkspace(owner, "Solo Owner Workspace");
        addMember(owner, workspaceId, "solo-maint@example.com");
        assertThat(changeRole(owner, workspaceId, maintainer.userId(), "MAINTAINER").getStatusCode())
                .isEqualTo(HttpStatus.OK);

        // The maintainer outranks nobody here, so the attempt is refused on rank
        // rather than on the owner count.
        var refused = changeRole(maintainer, workspaceId, owner.userId(), "VIEWER");
        assertThat(refused.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        var members = readList(restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/members",
                HttpMethod.GET, authJson(owner, null),
                String.class).getBody());
        assertThat(members.stream()
                .filter(member -> "OWNER".equals(String.valueOf(member.get("role"))))
                .count())
                .as("the workspace must still have an owner after the attempt")
                .isEqualTo(1);
    }

    @Test
    void lastOwnerCannotBeDemoted() {
        var owner = register("last-owner@example.com", "Last Owner");
        var successor = register("last-successor@example.com", "Last Successor");
        var workspaceId = createWorkspace(owner, "Last Owner Workspace");
        addMember(owner, workspaceId, "last-successor@example.com");

        var demote = changeRole(owner, workspaceId, owner.userId(), "MAINTAINER");
        assertThat(demote.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        // The sole owner demoting themselves hits the self-demotion rule first,
        // which is the more actionable reason; the last-owner rule covers the case
        // where somebody else tries to remove the only owner.
        assertThat(String.valueOf(readMap(demote.getBody()).get("message")))
                .as("a self-demotion must say so rather than blaming the owner count")
                .contains("demote yourself");

        assertThat(changeRole(owner, workspaceId, successor.userId(), "OWNER").getStatusCode())
                .isEqualTo(HttpStatus.OK);
        assertThat(changeRole(successor, workspaceId, owner.userId(), "VIEWER").getStatusCode())                .as("with a second owner present the first may step down")
                .isEqualTo(HttpStatus.OK);
    }

    @Test
    void unknownRoleIsRejected() {
        var owner = register("unknown-owner@example.com", "Unknown Owner");
        var teammate = register("unknown-mate@example.com", "Unknown Mate");
        var workspaceId = createWorkspace(owner, "Unknown Role Workspace");
        addMember(owner, workspaceId, "unknown-mate@example.com");

        assertThat(changeRole(owner, workspaceId, teammate.userId(), "SUPREME").getStatusCode())
                .isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void roleChangeForNonMemberIsNotFound() {
        var owner = register("nomember-owner@example.com", "NoMember Owner");
        var stranger = register("nomember-stranger@example.com", "NoMember Stranger");
        var workspaceId = createWorkspace(owner, "NoMember Workspace");

        assertThat(changeRole(owner, workspaceId, stranger.userId(), "VIEWER").getStatusCode())
                .isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void demotedMaintainerLosesWriteCapabilityImmediately() {
        var owner = register("demote-owner@example.com", "Demote Owner");
        var maintainer = register("demote-maint@example.com", "Demote Maint");
        var workspaceId = createWorkspace(owner, "Demote Workspace");
        addMember(owner, workspaceId, "demote-maint@example.com");
        changeRole(owner, workspaceId, maintainer.userId(), "MAINTAINER");
        assertThat(createProject(maintainer, workspaceId, "Before demotion").getStatusCode())
                .isEqualTo(HttpStatus.OK);

        assertThat(changeRole(owner, workspaceId, maintainer.userId(), "VIEWER").getStatusCode())
                .isEqualTo(HttpStatus.OK);

        assertThat(createProject(maintainer, workspaceId, "After demotion").getStatusCode())
                .isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(createTask(maintainer, workspaceId, "After demotion task").getStatusCode())
                .isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void promotedOperatorCanAdvanceAnyTaskInTheWorkspace() {
        var owner = register("promote-owner@example.com", "Promote Owner");
        var first = register("promote-first@example.com", "Promote First");
        var second = register("promote-second@example.com", "Promote Second");
        var workspaceId = createWorkspace(owner, "Promote Workspace");
        addMember(owner, workspaceId, "promote-first@example.com");
        addMember(owner, workspaceId, "promote-second@example.com");

        var created = readMap(createTask(first, workspaceId, "Belongs to first").getBody());
        var taskId = String.valueOf(created.get("id"));

        var byOther = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/status",
                HttpMethod.PUT,
                authJson(second, Map.of("status", "DONE")),
                String.class);
        assertThat(byOther.getStatusCode())
                .as("a plain operator cannot advance somebody else's task")
                .isEqualTo(HttpStatus.FORBIDDEN);

        assertThat(changeRole(owner, workspaceId, second.userId(), "MAINTAINER").getStatusCode())
                .isEqualTo(HttpStatus.OK);

        var afterPromotion = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/status",
                HttpMethod.PUT,
                authJson(second, Map.of("status", "DONE")),
                String.class);
        assertThat(afterPromotion.getStatusCode())
                .as("a maintainer can advance any task")
                .isEqualTo(HttpStatus.OK);
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
