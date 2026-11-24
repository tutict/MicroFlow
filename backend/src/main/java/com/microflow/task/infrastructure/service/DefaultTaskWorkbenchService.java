package com.microflow.task.infrastructure.service;

import com.microflow.common.error.ConcurrentModificationException;
import com.microflow.common.error.ResourceNotFoundException;
import com.microflow.task.application.service.TaskWorkbenchService;
import com.microflow.task.application.service.TaskRunStateLookup;
import com.microflow.task.domain.model.TaskActivity;
import com.microflow.task.domain.model.TaskDecision;
import com.microflow.task.domain.model.TaskItem;
import com.microflow.task.domain.model.TaskPriority;
import com.microflow.task.domain.model.TaskProject;
import com.microflow.task.domain.model.TaskStatus;
import com.microflow.task.infrastructure.persistence.JdbcTaskDecisionRepository;
import com.microflow.task.infrastructure.persistence.JdbcTaskRepository;
import com.microflow.workspace.application.service.WorkspaceAccessGuard;
import com.microflow.workspace.domain.model.WorkspaceRole;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Service;

@Service
public class DefaultTaskWorkbenchService implements TaskWorkbenchService {

    private static final int DEFAULT_LIMIT = 100;
    private static final int MAX_LIMIT = 200;

    private final JdbcTaskRepository taskRepository;
    private final JdbcTaskDecisionRepository decisionRepository;
    private final WorkspaceAccessGuard accessGuard;
    private final TaskRunStateLookup runStateLookup;

    public DefaultTaskWorkbenchService(
            JdbcTaskRepository taskRepository,
            JdbcTaskDecisionRepository decisionRepository,
            WorkspaceAccessGuard accessGuard,
            TaskRunStateLookup runStateLookup
    ) {
        this.taskRepository = taskRepository;
        this.decisionRepository = decisionRepository;
        this.accessGuard = accessGuard;
        this.runStateLookup = runStateLookup;
    }

    @Override
    public List<TaskProject> listProjects(String userId, String workspaceId) {
        accessGuard.requireMember(workspaceId, userId);
        return taskRepository.findProjects(workspaceId);
    }

    @Override
    public TaskProject createProject(String userId, String workspaceId, String name, String description) {
        accessGuard.requireProjectAdmin(workspaceId, userId);
        var trimmedName = name == null ? "" : name.trim();
        if (trimmedName.isEmpty()) {
            throw new IllegalArgumentException("Project name is required");
        }
        var projectId = taskRepository.createProject(
                workspaceId, trimmedName, normalize(description), userId);
        return taskRepository.findProjects(workspaceId).stream()
                .filter(project -> project.id().equals(projectId))
                .findFirst()
                .orElseThrow(() -> new ResourceNotFoundException("Project not created: " + projectId));
    }

    @Override
    public List<TaskItem> listTasks(
            String userId,
            String workspaceId,
            String projectId,
            String statusFilter,
            String assigneeFilter,
            boolean mineOnly,
            int limit
    ) {
        accessGuard.requireMember(workspaceId, userId);
        if (!taskRepository.projectExists(workspaceId, projectId)) {
            throw new ResourceNotFoundException("Project not found: " + projectId);
        }

        var status = parseStatusFilter(statusFilter);
        var assigneeUserId = mineOnly ? userId : null;
        var unassignedOnly = "unassigned".equalsIgnoreCase(assigneeFilter);
        if (!mineOnly && !unassignedOnly && assigneeFilter != null && !assigneeFilter.isBlank()) {
            assigneeUserId = assigneeFilter;
        }
        return taskRepository.findTasks(
                workspaceId,
                projectId,
                status,
                assigneeUserId,
                unassignedOnly,
                clampLimit(limit)
        );
    }

    @Override
    public TaskItem createTask(String userId, String workspaceId, CreateTaskCommand command) {
        accessGuard.requireCapability(
                workspaceId, userId, WorkspaceRole.Capability.CREATE_TASK);
        var title = command.title() == null ? "" : command.title().trim();
        if (title.isEmpty()) {
            throw new IllegalArgumentException("Task title is required");
        }
        if (!taskRepository.projectExists(workspaceId, command.projectId())) {
            throw new ResourceNotFoundException("Project not found: " + command.projectId());
        }
        if (command.originChannelId() != null && !command.originChannelId().isBlank()
                && !taskRepository.channelExists(workspaceId, command.originChannelId())) {
            throw new ResourceNotFoundException(
                    "Origin channel not found in workspace: " + command.originChannelId());
        }
        if (command.originMessageId() != null && !command.originMessageId().isBlank()
                && !taskRepository.messageExists(workspaceId, command.originMessageId())) {
            throw new ResourceNotFoundException(
                    "Origin message not found in workspace: " + command.originMessageId());
        }

        var requestedAssignee = command.assigneeUserId();
        boolean assignToOther = requestedAssignee != null
                && !requestedAssignee.isBlank()
                && !requestedAssignee.equals(userId)
                && !command.assigneeIsSelf();
        if (assignToOther) {
            accessGuard.requireCapability(
                    workspaceId, userId, WorkspaceRole.Capability.ASSIGN_ANY_TASK);
        }
        var assigneeUserId = resolveAssignee(
                workspaceId, userId, requestedAssignee, command.assigneeIsSelf());
        var status = parseStatusFilter(command.status());
        if (status == null) {
            status = TaskStatus.OPEN;
        }
        var taskId = taskRepository.createTask(
                workspaceId,
                emptyToNull(command.projectId()),
                title,
                normalize(command.detail()),
                status,
                TaskPriority.fromStored(command.priority()),
                assigneeUserId,
                userId,
                emptyToNull(command.originChannelId()),
                emptyToNull(command.originMessageId()),
                command.dueAt()
        );
        taskRepository.recordActivity(taskId, workspaceId, userId, "CREATED", null,
                status.storedValue(), null);
        return requireTask(workspaceId, taskId);
    }

    @Override
    public TaskItem updateTaskStatus(String userId, String workspaceId, String taskId, String targetStatus) {
        accessGuard.requireTaskWriteAccess(workspaceId, taskId, userId);
        var current = requireTask(workspaceId, taskId);
        var target = parseStatusFilter(targetStatus);
        if (target == null) {
            throw new IllegalArgumentException("A valid status is required");
        }
        if (!current.status().canTransitionTo(target)) {
            throw new IllegalArgumentException(
                    "Illegal task transition " + current.status().storedValue() + " -> " + target.storedValue()
                            + "; allowed: " + current.status().allowedTargets());
        }
        if (!taskRepository.applyStatus(taskId, current.status(), target)) {
            // Another writer moved the task first; recording the transition now
            // would leave the activity trail claiming a change that never landed.
            throw new ConcurrentModificationException(
                    "Task " + taskId + " changed concurrently; reload and try again");
        }
        taskRepository.recordActivity(taskId, workspaceId, userId, "STATUS_CHANGED",
                current.status().storedValue(), target.storedValue(), null);
        return requireTask(workspaceId, taskId);
    }

    @Override
    public TaskItem assignTask(
            String userId,
            String workspaceId,
            String taskId,
            String assigneeUserId,
            boolean assigneeIsSelf
    ) {
        accessGuard.requireAssigneeWriteAccess(workspaceId, taskId, userId);
        var current = requireTask(workspaceId, taskId);
        boolean assigningToOther = assigneeUserId != null
                && !assigneeUserId.isBlank()
                && !assigneeUserId.equals(userId)
                && !assigneeIsSelf;
        if (assigningToOther) {
            accessGuard.requireCapability(
                    workspaceId, userId, WorkspaceRole.Capability.ASSIGN_ANY_TASK);
        }
        var target = resolveAssignee(workspaceId, userId, assigneeUserId, assigneeIsSelf);
        taskRepository.applyAssignee(taskId, target);
        taskRepository.recordActivity(taskId, workspaceId, userId, "ASSIGNED",
                current.assigneeUserId(), target, null);
        return requireTask(workspaceId, taskId);
    }

    @Override
    public List<TaskActivity> listActivity(String userId, String workspaceId, String taskId) {
        accessGuard.requireMember(workspaceId, userId);
        requireTask(workspaceId, taskId);
        return taskRepository.findActivity(workspaceId, taskId, 200);
    }

    @Override
    public TaskSummaryCounts summarize(String userId, String workspaceId, String projectId) {
        accessGuard.requireMember(workspaceId, userId);
        var total = 0L;
        for (var status : TaskStatus.values()) {
            total += taskRepository.countByStatus(workspaceId, projectId, status.storedValue());
        }
        return new TaskSummaryCounts(
                total,
                taskRepository.countByStatus(workspaceId, projectId, TaskStatus.OPEN.storedValue()),
                taskRepository.countByStatus(workspaceId, projectId, TaskStatus.IN_PROGRESS.storedValue()),
                taskRepository.countByStatus(workspaceId, projectId, TaskStatus.BLOCKED.storedValue()),
                taskRepository.countByStatus(workspaceId, projectId, TaskStatus.DONE.storedValue())
        );
    }

    @Override
    public Optional<TaskItem> findVisible(String userId, String workspaceId, String taskId) {
        if (!accessGuard.isMember(workspaceId, userId)) {
            return Optional.empty();
        }
        return taskRepository.findTask(workspaceId, taskId);
    }

    @Override
    public MyWorkAgenda myWork(String userId, String workspaceId, int limit) {
        accessGuard.requireMember(workspaceId, userId);
        var capped = clampLimit(limit);

        var assignedToMe = taskRepository.findTasks(
                workspaceId, null, null, userId, false, capped);
        // Creating a task and then handing it to someone else does not make it my
        // work; only unowned work I raised stays on my agenda. The predicate is
        // applied in SQL so a busy workspace cannot push my older items off the
        // end of a window-wide LIMIT.
        var createdByMe = taskRepository.findUnassignedCreatedBy(workspaceId, userId, capped);

        var actionable = new java.util.ArrayList<TaskItem>();
        var blocked = new java.util.ArrayList<TaskItem>();
        var awaitingOthers = new java.util.ArrayList<TaskItem>();
        var recentlyDone = new java.util.ArrayList<TaskItem>();
        var running = new java.util.ArrayList<TaskItem>();
        var waitingApproval = new java.util.ArrayList<TaskItem>();
        var seen = new java.util.HashSet<String>();
        var relevantTasks = java.util.stream.Stream.concat(assignedToMe.stream(), createdByMe.stream())
                .filter(task -> seen.add(task.id())).toList();
        var runStates = runStateLookup.statesForTasks(workspaceId,
                relevantTasks.stream().map(TaskItem::id).toList());
        for (var task : relevantTasks) {
            bucket(task, runStates.get(task.id()), actionable, blocked, awaitingOthers, recentlyDone,
                    running, waitingApproval);
        }

        actionable.sort(dueFirst());
        blocked.sort(dueFirst());
        awaitingOthers.sort(dueFirst());
        running.sort(dueFirst());
        waitingApproval.sort(dueFirst());
        recentlyDone.sort((left, right) -> {
            var leftAt = left.completedAt() == null ? left.createdAt() : left.completedAt();
            var rightAt = right.completedAt() == null ? right.createdAt() : right.completedAt();
            if (leftAt == null) {
                return 1;
            }
            if (rightAt == null) {
                return -1;
            }
            return rightAt.compareTo(leftAt);
        });

        return new MyWorkAgenda(
                List.copyOf(actionable),
                List.copyOf(blocked),
                List.copyOf(awaitingOthers),
                recentlyDone.stream().limit(5).toList(),
                List.copyOf(running),
                List.copyOf(waitingApproval),
                actionable.size(),
                blocked.size(),
                awaitingOthers.size(),
                running.size(),
                waitingApproval.size()
        );
    }

    private void bucket(
            TaskItem task,
            TaskRunStateLookup.State runState,
            List<TaskItem> actionable,
            List<TaskItem> blocked,
            List<TaskItem> awaitingOthers,
            List<TaskItem> recentlyDone,
            List<TaskItem> running,
            List<TaskItem> waitingApproval
    ) {
        if (task.status() == TaskStatus.DONE || task.status() == TaskStatus.CANCELLED) {
            recentlyDone.add(task);
        } else if (runState == TaskRunStateLookup.State.WAITING_APPROVAL) {
            waitingApproval.add(task);
        } else if (runState == TaskRunStateLookup.State.RUNNING) {
            running.add(task);
        } else if (task.status() == TaskStatus.BLOCKED) {
            blocked.add(task);
        } else if (task.isUnassigned()) {
            awaitingOthers.add(task);
        } else {
            actionable.add(task);
        }
    }

    private Comparator<TaskItem> dueFirst() {
        return (left, right) -> {
            if (left.dueAt() == null && right.dueAt() == null) {
                return right.createdAt() == null || left.createdAt() == null
                        ? 0
                        : right.createdAt().compareTo(left.createdAt());
            }
            if (left.dueAt() == null) {
                return 1;
            }
            if (right.dueAt() == null) {
                return -1;
            }
            return left.dueAt().compareTo(right.dueAt());
        };
    }

    @Override
    public List<TaskDecision> listDecisions(String userId, String workspaceId, String taskId) {
        accessGuard.requireMember(workspaceId, userId);
        requireTask(workspaceId, taskId);
        return decisionRepository.findByTask(workspaceId, taskId);
    }

    @Override
    public TaskDecision recordDecision(
            String userId,
            String workspaceId,
            String taskId,
            RecordDecisionCommand command
    ) {
        accessGuard.requireTaskWriteAccess(workspaceId, taskId, userId);
        var summary = command.summary() == null ? "" : command.summary().trim();
        if (summary.isEmpty()) {
            throw new IllegalArgumentException("Decision summary is required");
        }
        if (summary.length() > 300) {
            throw new IllegalArgumentException("Decision summary must be 300 characters or fewer");
        }

        var supersedes = normalize(command.supersedesDecisionId());
        if (supersedes != null) {
            var target = decisionRepository.findDecision(workspaceId, supersedes)
                    .orElseThrow(() -> new ResourceNotFoundException(
                            "Superseded decision not found: " + supersedes));
            if (!target.taskId().equals(taskId)) {
                throw new IllegalArgumentException(
                        "A decision may only supersede another decision on the same task");
            }
        } else {
            decisionRepository.findLatest(workspaceId, taskId).ifPresent(latest -> {
                throw new IllegalArgumentException(
                        "This task already has a decision; pass supersedesDecisionId to replace it");
            });
        }

        var decisionId = decisionRepository.insert(
                workspaceId,
                taskId,
                supersedes,
                summary,
                normalize(command.rationale()),
                normalize(command.alternativesConsidered()),
                userId);
        taskRepository.recordActivity(
                taskId, workspaceId, userId, "DECISION_RECORDED", supersedes, summary, null);
        return decisionRepository.findDecision(workspaceId, decisionId)
                .orElseThrow(() -> new ResourceNotFoundException("Decision not found: " + decisionId));
    }

    private String resolveAssignee(
            String workspaceId,
            String actorUserId,
            String assigneeUserId,
            boolean assigneeIsSelf
    ) {
        if (assigneeIsSelf) {
            return actorUserId;
        }
        var target = emptyToNull(assigneeUserId);
        if (target == null) {
            return null;
        }
        if (!accessGuard.isMember(workspaceId, target)) {
            throw new IllegalArgumentException("Assignee must be a workspace member: " + target);
        }
        return target;
    }

    private TaskItem requireTask(String workspaceId, String taskId) {
        return taskRepository.findTask(workspaceId, taskId)
                .orElseThrow(() -> new ResourceNotFoundException("Task not found: " + taskId));
    }

    private TaskStatus parseStatusFilter(String value) {
        if (value == null || value.isBlank() || "ALL".equalsIgnoreCase(value)) {
            return null;
        }
        for (var status : TaskStatus.values()) {
            if (status.storedValue().equalsIgnoreCase(value)) {
                return status;
            }
        }
        return null;
    }

    private int clampLimit(int limit) {
        if (limit <= 0) {
            return DEFAULT_LIMIT;
        }
        return Math.min(limit, MAX_LIMIT);
    }

    private String normalize(String value) {
        if (value == null) {
            return null;
        }
        var trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private String emptyToNull(String value) {
        return value == null || value.isBlank() ? null : value;
    }
}
