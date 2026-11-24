package com.microflow.agent.runtime.infrastructure.tool;

import com.microflow.agent.runtime.domain.model.ToolDescriptor;
import com.microflow.agent.runtime.domain.model.ToolPolicy;
import com.microflow.agent.runtime.domain.model.AgentApprovalStatus;
import com.microflow.agent.runtime.domain.tool.AgentTool;
import com.microflow.agent.runtime.domain.tool.ToolContext;
import com.microflow.agent.runtime.domain.tool.ToolInputs;
import com.microflow.agent.runtime.domain.tool.ToolResult;
import com.microflow.task.domain.model.TaskStatus;
import com.microflow.task.infrastructure.persistence.JdbcTaskRepository;
import com.microflow.agent.runtime.infrastructure.persistence.JdbcAgentRuntimeRepository;
import com.microflow.workspace.application.service.WorkspaceAccessGuard;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Component;

/**
 * Moves a task through its state machine. Approval-gated: the runtime pauses and
 * asks a human before this runs, even though the write stays inside MicroFlow.
 */
@Component
public class TaskUpdateStatusTool implements AgentTool {

    private final JdbcTaskRepository taskRepository;
    private final JdbcAgentRuntimeRepository runtimeRepository;
    private final WorkspaceAccessGuard accessGuard;

    public TaskUpdateStatusTool(JdbcTaskRepository taskRepository,
            JdbcAgentRuntimeRepository runtimeRepository, WorkspaceAccessGuard accessGuard) {
        this.taskRepository = taskRepository;
        this.runtimeRepository = runtimeRepository;
        this.accessGuard = accessGuard;
    }

    @Override
    public ToolDescriptor descriptor() {
        return new ToolDescriptor(
                "task.update_status",
                "Update task status",
                "Changes the status of a task in this workspace. Requires human approval.",
                Map.of(
                        "type", "object",
                        "properties", Map.of(
                                "taskId", Map.of("type", "string"),
                                "status", Map.of(
                                        "type", "string",
                                        "enum", TaskStatus.allStoredValues())
                        ),
                        "required", List.of("status")
                ),
                ToolPolicy.Permission.APPROVAL,
                ToolPolicy.Risk.INTERNAL_WRITE,
                true,
                null
        );
    }

    @Override
    public void authorize(ToolContext context, String actorUserId, Map<String, Object> input) {
        var requested = ToolInputs.optionalString(input, "taskId");
        var taskId = requested == null ? context.taskId() : requested;
        if (taskId == null || taskId.isBlank()) {
            throw new IllegalArgumentException("This run is not attached to a task");
        }
        accessGuard.requireTaskWriteAccess(context.workspaceId(), taskId, actorUserId);
    }

    @Override
    public ToolResult invoke(ToolContext context, Map<String, Object> input) {
        var approval = context.approvalId() == null ? null
                : runtimeRepository.findApproval(context.approvalId()).orElse(null);
        if (approval == null || approval.status() != AgentApprovalStatus.APPROVED
                || !approval.sessionId().equals(context.sessionId())
                || !approval.workspaceId().equals(context.workspaceId())
                || !approval.toolKey().equals(descriptor().key())) {
            return ToolResult.failed("A valid task approval is required");
        }
        authorize(context, approval.decidedByUserId(), input);
        var requested = ToolInputs.optionalString(input, "taskId");
        var taskId = requested == null || requested.isBlank() ? context.taskId() : requested;
        if (taskId == null || taskId.isBlank()) {
            return ToolResult.failed("This run is not attached to a task");
        }
        var target = parseStatus(ToolInputs.requiredString(input, "status"));
        var task = taskRepository.findTask(context.workspaceId(), taskId);
        if (task.isEmpty()) {
            return ToolResult.failed("Task not found: " + taskId);
        }
        var current = task.get();
        if (current.status() == target) {
            return ToolResult.ok(Map.of("taskId", taskId, "status", target.storedValue()),
                    "Task already %s.".formatted(target.storedValue()));
        }
        if (!current.status().canTransitionTo(target)) {
            return ToolResult.failed("Task cannot move from %s to %s"
                    .formatted(current.status().storedValue(), target.storedValue()));
        }
        if (!taskRepository.applyStatus(taskId, current.status(), target)) {
            return ToolResult.failed("Task status changed while the run was waiting for approval");
        }
        taskRepository.recordActivity(
                taskId,
                context.workspaceId(),
                approval.decidedByUserId(),
                "STATUS_CHANGED",
                current.status().storedValue(),
                target.storedValue(),
                "Applied by agent run " + context.sessionId()
        );
        var payload = new LinkedHashMap<String, Object>();
        payload.put("taskId", taskId);
        payload.put("from", current.status().storedValue());
        payload.put("status", target.storedValue());
        return ToolResult.ok(payload, "Task moved from %s to %s."
                .formatted(current.status().storedValue(), target.storedValue()));
    }

    private TaskStatus parseStatus(String raw) {
        for (var status : TaskStatus.values()) {
            if (status.storedValue().equalsIgnoreCase(raw)) {
                return status;
            }
        }
        throw new IllegalArgumentException("Unknown task status: " + raw);
    }
}
