package com.microflow.task.infrastructure.persistence;

import com.microflow.workspace.application.service.TaskAccountabilityLookup;
import org.springframework.stereotype.Component;

@Component
public class JdbcTaskAccountabilityLookup implements TaskAccountabilityLookup {

    private final JdbcTaskRepository taskRepository;

    public JdbcTaskAccountabilityLookup(JdbcTaskRepository taskRepository) {
        this.taskRepository = taskRepository;
    }

    @Override
    public AccountableUsers find(String workspaceId, String taskId) {
        return taskRepository.findAccountableUsers(workspaceId, taskId)
                .map(users -> new AccountableUsers(users.assigneeUserId(), users.creatorUserId()))
                .orElse(null);
    }
}
