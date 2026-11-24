package com.microflow.task.api.rest;

import com.microflow.task.api.dto.AssignTaskRequest;
import com.microflow.task.api.dto.CreateTaskProjectRequest;
import com.microflow.task.api.dto.CreateTaskRequest;
import com.microflow.task.api.dto.MyWorkAgendaResponse;
import com.microflow.task.api.dto.RecordDecisionRequest;
import com.microflow.task.api.dto.TaskActivityResponse;
import com.microflow.task.api.dto.TaskDecisionResponse;
import com.microflow.task.api.dto.TaskProjectResponse;
import com.microflow.task.api.dto.TaskResponse;
import com.microflow.task.api.dto.TaskSummaryResponse;
import com.microflow.task.api.dto.UpdateTaskStatusRequest;
import com.microflow.task.api.mapper.TaskApiMapper;
import com.microflow.task.application.service.TaskWorkbenchService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.time.Instant;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class TaskController {

    private final TaskWorkbenchService taskWorkbenchService;
    private final TaskApiMapper taskApiMapper;

    public TaskController(TaskWorkbenchService taskWorkbenchService, TaskApiMapper taskApiMapper) {
        this.taskWorkbenchService = taskWorkbenchService;
        this.taskApiMapper = taskApiMapper;
    }

    @GetMapping("/workspaces/{workspaceId}/task-projects")
    public List<TaskProjectResponse> listProjects(
            @PathVariable String workspaceId,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return taskWorkbenchService.listProjects(userId, workspaceId).stream()
                .map(taskApiMapper::toResponse)
                .toList();
    }

    @PostMapping("/workspaces/{workspaceId}/task-projects")
    public TaskProjectResponse createProject(
            @PathVariable String workspaceId,
            @Valid @RequestBody CreateTaskProjectRequest body,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return taskApiMapper.toResponse(
                taskWorkbenchService.createProject(userId, workspaceId, body.name(), body.description()));
    }

    @GetMapping("/workspaces/{workspaceId}/tasks")
    public List<TaskResponse> listTasks(
            @PathVariable String workspaceId,
            HttpServletRequest request,
            @RequestParam(required = false) String projectId,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String assignee,
            @RequestParam(defaultValue = "false") boolean mine,
            @RequestParam(defaultValue = "100") int limit
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return taskWorkbenchService
                .listTasks(userId, workspaceId, projectId, status, assignee, mine, limit)
                .stream()
                .map(taskApiMapper::toResponse)
                .toList();
    }

    @PostMapping("/workspaces/{workspaceId}/tasks")
    public TaskResponse createTask(
            @PathVariable String workspaceId,
            @Valid @RequestBody CreateTaskRequest body,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        var command = new TaskWorkbenchService.CreateTaskCommand(
                body.projectId(),
                body.title(),
                body.detail(),
                body.status(),
                body.priority(),
                body.assigneeUserId(),
                Boolean.TRUE.equals(body.assigneeIsSelf()),
                body.originChannelId(),
                body.originMessageId(),
                parseInstant(body.dueAt())
        );
        return taskApiMapper.toResponse(
                taskWorkbenchService.createTask(userId, workspaceId, command));
    }

    @GetMapping("/workspaces/{workspaceId}/task-summary")
    public TaskSummaryResponse summarize(
            @PathVariable String workspaceId,
            HttpServletRequest request,
            @RequestParam(required = false) String projectId
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return taskApiMapper.toResponse(
                taskWorkbenchService.summarize(userId, workspaceId, projectId));
    }

    @GetMapping("/workspaces/{workspaceId}/my-work")
    public MyWorkAgendaResponse myWork(
            @PathVariable String workspaceId,
            HttpServletRequest request,
            @RequestParam(defaultValue = "50") int limit
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return taskApiMapper.toResponse(
                taskWorkbenchService.myWork(userId, workspaceId, limit));
    }

    @GetMapping("/workspaces/{workspaceId}/tasks/{taskId}/decisions")
    public List<TaskDecisionResponse> listDecisions(
            @PathVariable String workspaceId,
            @PathVariable String taskId,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return taskWorkbenchService.listDecisions(userId, workspaceId, taskId).stream()
                .map(taskApiMapper::toResponse)
                .toList();
    }

    @PostMapping("/workspaces/{workspaceId}/tasks/{taskId}/decisions")
    public TaskDecisionResponse recordDecision(
            @PathVariable String workspaceId,
            @PathVariable String taskId,
            @Valid @RequestBody RecordDecisionRequest body,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        var command = new TaskWorkbenchService.RecordDecisionCommand(
                body.summary(),
                body.rationale(),
                body.alternativesConsidered(),
                body.supersedesDecisionId());
        return taskApiMapper.toResponse(
                taskWorkbenchService.recordDecision(userId, workspaceId, taskId, command));
    }

    @GetMapping("/workspaces/{workspaceId}/tasks/{taskId}/activity")
    public List<TaskActivityResponse> listActivity(
            @PathVariable String workspaceId,
            @PathVariable String taskId,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return taskWorkbenchService.listActivity(userId, workspaceId, taskId).stream()
                .map(taskApiMapper::toResponse)
                .toList();
    }

    @PutMapping("/workspaces/{workspaceId}/tasks/{taskId}/status")
    public TaskResponse updateStatus(
            @PathVariable String workspaceId,
            @PathVariable String taskId,
            @Valid @RequestBody UpdateTaskStatusRequest body,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return taskApiMapper.toResponse(
                taskWorkbenchService.updateTaskStatus(userId, workspaceId, taskId, body.status()));
    }

    @PutMapping("/workspaces/{workspaceId}/tasks/{taskId}/assignee")
    public TaskResponse assign(
            @PathVariable String workspaceId,
            @PathVariable String taskId,
            @RequestBody(required = false) AssignTaskRequest body,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        var safeBody = body == null ? new AssignTaskRequest(null, false) : body;
        return taskApiMapper.toResponse(taskWorkbenchService.assignTask(
                userId,
                workspaceId,
                taskId,
                safeBody.assigneeUserId(),
                Boolean.TRUE.equals(safeBody.assigneeIsSelf())
        ));
    }

    private Instant parseInstant(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        try {
            return Instant.parse(value);
        } catch (RuntimeException ex) {
            throw new IllegalArgumentException("dueAt must be an ISO-8601 instant: " + value);
        }
    }
}
