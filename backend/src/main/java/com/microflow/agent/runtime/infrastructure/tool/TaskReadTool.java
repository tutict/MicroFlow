package com.microflow.agent.runtime.infrastructure.tool;

import com.microflow.agent.runtime.domain.model.ToolDescriptor;
import com.microflow.agent.runtime.domain.model.ToolPolicy;
import com.microflow.agent.runtime.domain.tool.AgentTool;
import com.microflow.agent.runtime.domain.tool.ToolContext;
import com.microflow.agent.runtime.domain.tool.ToolInputs;
import com.microflow.agent.runtime.domain.tool.ToolResult;
import com.microflow.task.infrastructure.persistence.JdbcTaskRepository;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Component;

/** Reads one task of the current workspace. */
@Component
public class TaskReadTool implements AgentTool {

    private final JdbcTaskRepository taskRepository;

    public TaskReadTool(JdbcTaskRepository taskRepository) {
        this.taskRepository = taskRepository;
    }

    @Override
    public ToolDescriptor descriptor() {
        return new ToolDescriptor(
                "task.read",
                "Read task",
                "Loads the task this run is attached to (or a task id passed in the input).",
                Map.of(
                        "type", "object",
                        "properties", Map.of("taskId", Map.of("type", "string"))
                ),
                ToolPolicy.Permission.AUTO,
                ToolPolicy.Risk.READ_ONLY,
                true,
                null
        );
    }

    @Override
    public ToolResult invoke(ToolContext context, Map<String, Object> input) {
        var requested = ToolInputs.optionalString(input, "taskId");
        var taskId = requested == null || requested.isBlank() ? context.taskId() : requested;
        if (taskId == null || taskId.isBlank()) {
            return ToolResult.failed("This run is not attached to a task");
        }
        var task = taskRepository.findTask(context.workspaceId(), taskId);
        if (task.isEmpty()) {
            return ToolResult.failed("Task not found: " + taskId);
        }
        var value = task.get();
        var payload = new LinkedHashMap<String, Object>();
        payload.put("id", value.id());
        payload.put("title", value.title());
        payload.put("detail", value.detail());
        payload.put("status", value.status().storedValue());
        payload.put("priority", value.priority().storedValue());
        payload.put("projectName", value.projectName());
        payload.put("assigneeDisplayName", value.assigneeDisplayName());
        payload.put("dueAt", value.dueAt() == null ? null : value.dueAt().toString());
        return ToolResult.ok(payload, "Task '%s' is %s.".formatted(value.title(), value.status().storedValue()));
    }
}
