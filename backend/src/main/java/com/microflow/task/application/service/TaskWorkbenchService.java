package com.microflow.task.application.service;

import com.microflow.task.domain.model.TaskActivity;
import com.microflow.task.domain.model.TaskDecision;
import com.microflow.task.domain.model.TaskItem;
import com.microflow.task.domain.model.TaskProject;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface TaskWorkbenchService {

    List<TaskProject> listProjects(String userId, String workspaceId);

    TaskProject createProject(String userId, String workspaceId, String name, String description);

    List<TaskItem> listTasks(
            String userId,
            String workspaceId,
            String projectId,
            String statusFilter,
            String assigneeFilter,
            boolean mineOnly,
            int limit
    );

    TaskItem createTask(
            String userId,
            String workspaceId,
            CreateTaskCommand command
    );

    TaskItem updateTaskStatus(String userId, String workspaceId, String taskId, String targetStatus);

    TaskItem assignTask(
            String userId,
            String workspaceId,
            String taskId,
            String assigneeUserId,
            boolean assigneeIsSelf
    );

    List<TaskActivity> listActivity(String userId, String workspaceId, String taskId);

    /**
     * Cross-project aggregation of the caller's own work, grouped by the next
     * useful action rather than by project.
     */
    MyWorkAgenda myWork(String userId, String workspaceId, int limit);

    List<TaskDecision> listDecisions(String userId, String workspaceId, String taskId);

    TaskDecision recordDecision(
            String userId,
            String workspaceId,
            String taskId,
            RecordDecisionCommand command
    );

    record RecordDecisionCommand(
            String summary,
            String rationale,
            String alternativesConsidered,
            String supersedesDecisionId
    ) {
    }

    /**
     * The caller's own workload. Buckets are mutually exclusive and ordered by
     * the action each one implies.
     */
    record MyWorkAgenda(
            List<TaskItem> actionable,
            List<TaskItem> blocked,
            List<TaskItem> awaitingOthers,
            List<TaskItem> recentlyDone,
            List<TaskItem> running,
            List<TaskItem> waitingApproval,
            int actionableCount,
            int blockedCount,
            int awaitingOthersCount,
            int runningCount,
            int waitingApprovalCount
    ) {
    }

    record CreateTaskCommand(
            String projectId,
            String title,
            String detail,
            String status,
            String priority,
            String assigneeUserId,
            boolean assigneeIsSelf,
            String originChannelId,
            String originMessageId,
            Instant dueAt
    ) {
    }

    record TaskSummaryCounts(long total, long open, long inProgress, long blocked, long done) {
    }

    TaskSummaryCounts summarize(String userId, String workspaceId, String projectId);

    Optional<TaskItem> findVisible(String userId, String workspaceId, String taskId);
}
