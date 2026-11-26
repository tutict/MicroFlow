package com.microflow.task;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.microflow.common.error.AccessDeniedException;
import com.microflow.common.error.ResourceNotFoundException;
import com.microflow.task.domain.model.TaskStatus;
import com.microflow.task.infrastructure.persistence.JdbcTaskRepository;
import com.microflow.task.infrastructure.service.DefaultTaskWorkbenchService;
import com.microflow.testing.QuarkusRestTemplate;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;
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
@TestProfile(TaskWorkbenchApiTests.Profile.class)
class TaskWorkbenchApiTests {

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
                    "microflow.jwt.secret", "task-test-jwt-secret-with-enough-entropy",
                    "microflow.crypto.secret", "ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA="
            );
        }
    }

    private static Path createDatabasePath() {
        try {
            return Files.createTempDirectory("microflow-task-tests").resolve("tasks.db");
        } catch (IOException exception) {
            throw new IllegalStateException("Unable to create a task test database path", exception);
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
    private DefaultTaskWorkbenchService taskService;

    @Inject
    private com.microflow.workspace.application.service.WorkspaceAccessGuard accessGuard;

    @TestHTTPResource("/")
    private URI baseUri;

    private Session register(String email, String displayName) {
        var response = restTemplate.exchange(
                "/api/v1/auth/register",
                HttpMethod.POST,
                json(Map.of("email", email, "password", "Passw0rd!2345", "displayName", displayName)),
                String.class
        );
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        var payload = readMap(response.getBody());
        return new Session(
                (String) payload.get("accessToken"),
                (String) payload.get("userId")
        );
    }

    private String createWorkspace(Session session, String name) {
        var response = restTemplate.exchange(
                "/api/v1/workspaces",
                HttpMethod.POST,
                authJson(session, Map.of("name", name)),
                String.class
        );
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return (String) readMap(response.getBody()).get("id");
    }

    private void addMember(String ownerToken, String workspaceId, String email) {
        var response = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/members",
                HttpMethod.POST,
                authJson(new Session(ownerToken, ""), Map.of("email", email)),
                String.class
        );
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    @Test
    void taskLifecycleWalksThroughStatusMachine() {
        var owner = register("lifecycle-owner@example.com", "Lifecycle Owner");
        var workspaceId = createWorkspace(owner, "Lifecycle Workspace");

        var createResponse = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks",
                HttpMethod.POST,
                authJson(owner, Map.of("title", "Ship the workbench", "priority", "HIGH")),
                String.class
        );
        assertThat(createResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        var created = readMap(createResponse.getBody());
        var taskId = (String) created.get("id");
        assertThat(created.get("status")).isEqualTo("OPEN");
        assertThat(created.get("priority")).isEqualTo("HIGH");

        var inProgress = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/status",
                HttpMethod.PUT,
                authJson(owner, Map.of("status", "IN_PROGRESS")),
                String.class
        );
        assertThat(inProgress.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(readMap(inProgress.getBody()).get("status")).isEqualTo("IN_PROGRESS");

        var done = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/status",
                HttpMethod.PUT,
                authJson(owner, Map.of("status", "DONE")),
                String.class
        );
        assertThat(done.getStatusCode()).isEqualTo(HttpStatus.OK);
        var donePayload = readMap(done.getBody());
        assertThat(donePayload.get("status")).isEqualTo("DONE");
        assertThat(donePayload.get("completedAt")).isNotNull();
    }

    @Test
    void cancelledTaskCannotJumpStraightToDone() {
        var owner = register("cancel-owner@example.com", "Cancel Owner");
        var workspaceId = createWorkspace(owner, "Cancel Workspace");

        var created = readMap(restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks",
                HttpMethod.POST,
                authJson(owner, Map.of("title", "Abandoned task")),
                String.class
        ).getBody());
        var taskId = (String) created.get("id");

        var cancelled = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/status",
                HttpMethod.PUT,
                authJson(owner, Map.of("status", "CANCELLED")),
                String.class
        );
        assertThat(cancelled.getStatusCode()).isEqualTo(HttpStatus.OK);

        var illegal = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/status",
                HttpMethod.PUT,
                authJson(owner, Map.of("status", "DONE")),
                String.class
        );
        assertThat(illegal.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void nonMemberCannotReadOrMutateWorkspaceTasks() {
        var owner = register("guard-owner@example.com", "Guard Owner");
        var outsider = register("outsider@example.com", "Outsider");
        var workspaceId = createWorkspace(owner, "Guard Workspace");

        var created = readMap(restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks",
                HttpMethod.POST,
                authJson(owner, Map.of("title", "Owner only task")),
                String.class
        ).getBody());
        var taskId = (String) created.get("id");

        var listResponse = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks",
                HttpMethod.GET,
                bearerJson(outsider),
                String.class
        );
        assertThat(listResponse.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        var statusResponse = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/status",
                HttpMethod.PUT,
                authJson(outsider, Map.of("status", "DONE")),
                String.class
        );
        assertThat(statusResponse.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        var projectResponse = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/task-projects",
                HttpMethod.GET,
                bearerJson(outsider),
                String.class
        );
        assertThat(projectResponse.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        var summaryResponse = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/task-summary",
                HttpMethod.GET,
                bearerJson(outsider),
                String.class
        );
        assertThat(summaryResponse.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void memberWithoutAssignmentCannotChangeStatusOfSomeoneElsesTask() {
        var owner = register("assign-owner@example.com", "Assign Owner");
        var teammate = register("teammate@example.com", "Teammate");
        var workspaceId = createWorkspace(owner, "Assignment Workspace");
        addMember(owner.token(), workspaceId, "teammate@example.com");

        var created = readMap(restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks",
                HttpMethod.POST,
                authJson(owner, Map.of("title", "Assigned to owner")),
                String.class
        ).getBody());
        var taskId = (String) created.get("id");

        var rejected = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/status",
                HttpMethod.PUT,
                authJson(teammate, Map.of("status", "DONE")),
                String.class
        );
        assertThat(rejected.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        var ownerAssignsTeammate = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/assignee",
                HttpMethod.PUT,
                authJson(owner, Map.of("assigneeUserId", teammate.userId())),
                String.class
        );
        assertThat(ownerAssignsTeammate.getStatusCode()).isEqualTo(HttpStatus.OK);

        var nowAllowed = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/status",
                HttpMethod.PUT,
                authJson(teammate, Map.of("status", "DONE")),
                String.class
        );
        assertThat(nowAllowed.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    @Test
    void memberCanReadTasksOfSharedWorkspace() {
        var owner = register("shared-owner@example.com", "Shared Owner");
        var teammate = register("shared-teammate@example.com", "Shared Teammate");
        var workspaceId = createWorkspace(owner, "Shared Workspace");
        addMember(owner.token(), workspaceId, "shared-teammate@example.com");

        restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks",
                HttpMethod.POST,
                authJson(owner, Map.of("title", "Visible task")),
                String.class
        );

        var response = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks",
                HttpMethod.GET,
                bearerJson(teammate),
                String.class
        );
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(readList(response.getBody())).hasSize(1);
    }

    @Test
    void assigneeMustBeWorkspaceMember() {
        var owner = register("assignee-owner@example.com", "Assignee Owner");
        var workspaceId = createWorkspace(owner, "Assignee Workspace");
        register("stranger@example.com", "Stranger");

        var response = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks",
                HttpMethod.POST,
                authJson(owner, Map.of(
                        "title", "Task with bad assignee",
                        "assigneeUserId", "usr_stranger"
                )),
                String.class
        );
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void projectGroupingCountsOpenAndTotalTasks() {
        var owner = register("project-owner@example.com", "Project Owner");
        var workspaceId = createWorkspace(owner, "Project Workspace");

        var project = readMap(restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/task-projects",
                HttpMethod.POST,
                authJson(owner, Map.of("name", "Q1 Rollout", "description", "First quarter")),
                String.class
        ).getBody());
        var projectId = (String) project.get("id");
        assertThat(project.get("name")).isEqualTo("Q1 Rollout");

        restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks",
                HttpMethod.POST,
                authJson(owner, Map.of("title", "Task A", "projectId", projectId)),
                String.class
        );
        restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks",
                HttpMethod.POST,
                authJson(owner, Map.of("title", "Task B", "projectId", projectId)),
                String.class
        );

        var projects = readList(restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/task-projects",
                HttpMethod.GET,
                bearerJson(owner),
                String.class
        ).getBody());
        assertThat(projects).hasSize(1);
        assertThat(((Number) projects.get(0).get("taskCount")).intValue()).isEqualTo(2);
        assertThat(((Number) projects.get(0).get("openTaskCount")).intValue()).isEqualTo(2);

        var summary = readMap(restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/task-summary?projectId=" + projectId,
                HttpMethod.GET,
                bearerJson(owner),
                String.class
        ).getBody());
        assertThat(((Number) summary.get("total")).intValue()).isEqualTo(2);
        assertThat(((Number) summary.get("open")).intValue()).isEqualTo(2);
    }

    @Test
    void tasksFromAnotherWorkspaceProjectAreNotVisible() {
        var owner = register("cross-owner@example.com", "Cross Owner");
        var firstWorkspace = createWorkspace(owner, "First Workspace");
        var secondWorkspace = createWorkspace(owner, "Second Workspace");

        var created = readMap(restTemplate.exchange(
                "/api/v1/workspaces/" + firstWorkspace + "/tasks",
                HttpMethod.POST,
                authJson(owner, Map.of("title", "Private to first workspace")),
                String.class
        ).getBody());
        var taskId = (String) created.get("id");

        var response = restTemplate.exchange(
                "/api/v1/workspaces/" + secondWorkspace + "/tasks?status=OPEN",
                HttpMethod.GET,
                bearerJson(owner),
                String.class
        );
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(readList(response.getBody())).isEmpty();
    }

    @Test
    void taskActivityRecordsCreationAndStatusChange() {
        var owner = register("activity-owner@example.com", "Activity Owner");
        var workspaceId = createWorkspace(owner, "Activity Workspace");

        var created = readMap(restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks",
                HttpMethod.POST,
                authJson(owner, Map.of("title", "Tracked task")),
                String.class
        ).getBody());
        var taskId = (String) created.get("id");

        restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/status",
                HttpMethod.PUT,
                authJson(owner, Map.of("status", "BLOCKED")),
                String.class
        );

        var activity = readList(restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/activity",
                HttpMethod.GET,
                bearerJson(owner),
                String.class
        ).getBody());
        assertThat(activity).hasSize(2);
        assertThat(activity.get(0).get("eventType")).isEqualTo("CREATED");
        assertThat(activity.get(1).get("eventType")).isEqualTo("STATUS_CHANGED");
        assertThat(activity.get(1).get("fromValue")).isEqualTo("OPEN");
        assertThat(activity.get(1).get("toValue")).isEqualTo("BLOCKED");
    }

    @Test
    void statusStateMachineAllowsEveryDocumentedTransition() {
        assertThat(TaskStatus.OPEN.canTransitionTo(TaskStatus.DONE)).isTrue();
        assertThat(TaskStatus.IN_PROGRESS.canTransitionTo(TaskStatus.BLOCKED)).isTrue();
        assertThat(TaskStatus.BLOCKED.canTransitionTo(TaskStatus.IN_PROGRESS)).isTrue();
        assertThat(TaskStatus.DONE.canTransitionTo(TaskStatus.OPEN)).isTrue();
        assertThat(TaskStatus.CANCELLED.canTransitionTo(TaskStatus.DONE)).isFalse();
        assertThat(TaskStatus.CANCELLED.canTransitionTo(TaskStatus.BLOCKED)).isFalse();
        assertThat(TaskStatus.DONE.canTransitionTo(TaskStatus.BLOCKED)).isFalse();
        assertThat(TaskStatus.fromStored("nonsense")).isEqualTo(TaskStatus.OPEN);
        assertThat(TaskStatus.fromStored("done")).isEqualTo(TaskStatus.DONE);
    }

    @Test
    void serviceRejectsMissingTaskAndDeniedCallerDirectly() {
        var owner = register("guard-unit@example.com", "Guard Unit");
        var outsider = register("guard-outsider@example.com", "Guard Outsider");
        var workspaceId = createWorkspace(owner, "Guard Unit Workspace");

        var created = taskService.createTask(
                owner.userId(),
                workspaceId,
                new com.microflow.task.application.service.TaskWorkbenchService.CreateTaskCommand(
                        null, "Unit task", null, null, null, null, false, null, null, null));
        var taskId = created.id();

        assertThatThrownBy(() -> accessGuard.requireMember(workspaceId, "usr_missing"))
                .isInstanceOf(AccessDeniedException.class);
        assertThatThrownBy(() -> accessGuard.requireTaskWriteAccess(workspaceId, taskId, outsider.userId()))
                .isInstanceOf(AccessDeniedException.class);
        assertThatThrownBy(() -> accessGuard.requireTaskWriteAccess(workspaceId, "task_missing", owner.userId()))
                .isInstanceOf(ResourceNotFoundException.class);

        assertThat(taskRepository.findTask(workspaceId, taskId)).isPresent();
        assertThat(taskRepository.findTask(workspaceId, "task_missing")).isEmpty();
    }

    @Test
    void missingAuthenticationIsRejectedByTheJwtBoundary() {
        var response = restTemplate.getForEntity("/api/v1/workspaces/ws_missing/tasks", String.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    private HttpEntity<?> json(Map<String, Object> body) {
        return authJson(null, body);
    }

    private HttpEntity<?> authJson(Session session, Map<String, Object> body) {
        var headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        if (session != null && !session.token().isEmpty()) {
            headers.setBearerAuth(session.token());
        }
        return new HttpEntity<>(body, headers);
    }

    private HttpEntity<?> bearerJson(Session session) {
        return authJson(session, null);
    }

    @SuppressWarnings("unchecked")
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
