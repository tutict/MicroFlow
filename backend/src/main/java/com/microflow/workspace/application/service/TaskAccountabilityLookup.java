package com.microflow.workspace.application.service;

/**
 * Resolves who is accountable for a task. Injected into the access guard so the
 * workspace boundary does not depend on the task domain module, keeping the
 * dependency direction one-way.
 */
@FunctionalInterface
public interface TaskAccountabilityLookup {

    /**
     * @return the assignee and creator user ids for the task, or {@code null} when
     *     the task does not exist in the given workspace
     */
    AccountableUsers find(String workspaceId, String taskId);

    record AccountableUsers(String assigneeUserId, String creatorUserId) {

        public boolean involves(String userId) {
            if (userId == null) {
                return false;
            }
            return userId.equals(assigneeUserId) || userId.equals(creatorUserId);
        }
    }
}
