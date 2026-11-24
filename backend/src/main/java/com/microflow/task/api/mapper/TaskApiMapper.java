package com.microflow.task.api.mapper;

import com.microflow.task.api.dto.MyWorkAgendaResponse;
import com.microflow.task.api.dto.TaskActivityResponse;
import com.microflow.task.api.dto.TaskDecisionResponse;
import com.microflow.task.api.dto.TaskProjectResponse;
import com.microflow.task.api.dto.TaskResponse;
import com.microflow.task.api.dto.TaskSummaryResponse;
import com.microflow.task.application.service.TaskWorkbenchService;
import com.microflow.task.domain.model.TaskActivity;
import com.microflow.task.domain.model.TaskDecision;
import com.microflow.task.domain.model.TaskItem;
import com.microflow.task.domain.model.TaskProject;
import org.springframework.stereotype.Component;

@Component
public class TaskApiMapper {

    public TaskResponse toResponse(TaskItem task) {
        return new TaskResponse(
                task.id(),
                task.workspaceId(),
                task.projectId(),
                task.projectName(),
                task.title(),
                task.detail(),
                task.status().storedValue(),
                task.priority().storedValue(),
                task.assigneeUserId(),
                task.assigneeDisplayName(),
                task.creatorUserId(),
                task.originChannelId(),
                task.originMessageId(),
                task.dueAt(),
                task.createdAt(),
                task.updatedAt(),
                task.completedAt()
        );
    }

    public TaskProjectResponse toResponse(TaskProject project) {
        return new TaskProjectResponse(
                project.id(),
                project.workspaceId(),
                project.name(),
                project.description(),
                project.status(),
                project.createdByUserId(),
                project.taskCount(),
                project.openTaskCount()
        );
    }

    public TaskActivityResponse toResponse(TaskActivity activity) {
        return new TaskActivityResponse(
                activity.id(),
                activity.taskId(),
                activity.actorUserId(),
                activity.actorDisplayName(),
                activity.eventType(),
                activity.fromValue(),
                activity.toValue(),
                activity.note(),
                activity.createdAt()
        );
    }

    public TaskSummaryResponse toResponse(TaskWorkbenchService.TaskSummaryCounts counts) {
        return new TaskSummaryResponse(
                counts.total(), counts.open(), counts.inProgress(), counts.blocked(), counts.done());
    }

    public MyWorkAgendaResponse toResponse(TaskWorkbenchService.MyWorkAgenda agenda) {
        return new MyWorkAgendaResponse(
                agenda.actionable().stream().map(this::toResponse).toList(),
                agenda.blocked().stream().map(this::toResponse).toList(),
                agenda.awaitingOthers().stream().map(this::toResponse).toList(),
                agenda.recentlyDone().stream().map(this::toResponse).toList(),
                agenda.running().stream().map(this::toResponse).toList(),
                agenda.waitingApproval().stream().map(this::toResponse).toList(),
                agenda.actionableCount(),
                agenda.blockedCount(),
                agenda.awaitingOthersCount(),
                agenda.runningCount(),
                agenda.waitingApprovalCount());
    }

    public TaskDecisionResponse toResponse(TaskDecision decision) {
        return new TaskDecisionResponse(
                decision.id(),
                decision.workspaceId(),
                decision.taskId(),
                decision.sequenceNo(),
                decision.supersedesDecisionId(),
                decision.summary(),
                decision.rationale(),
                decision.alternativesConsidered(),
                decision.decidedByUserId(),
                decision.decidedByDisplayName(),
                decision.createdAt());
    }
}
