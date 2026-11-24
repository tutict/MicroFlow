package com.microflow.task.domain.model;

import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Task status state machine. Transitions are explicit so illegal moves fail loudly
 * instead of silently corrupting workflow state.
 */
public enum TaskStatus {

    OPEN("OPEN"),
    IN_PROGRESS("IN_PROGRESS"),
    BLOCKED("BLOCKED"),
    DONE("DONE"),
    CANCELLED("CANCELLED");

    private static final Map<TaskStatus, Set<TaskStatus>> ALLOWED_TRANSITIONS = Map.of(
            OPEN, Set.of(IN_PROGRESS, BLOCKED, DONE, CANCELLED),
            IN_PROGRESS, Set.of(OPEN, BLOCKED, DONE, CANCELLED),
            BLOCKED, Set.of(OPEN, IN_PROGRESS, CANCELLED),
            DONE, Set.of(OPEN, IN_PROGRESS),
            CANCELLED, Set.of(OPEN)
    );

    private static final List<TaskStatus> STATUSES = List.of(values());

    private final String storedValue;

    TaskStatus(String storedValue) {
        this.storedValue = storedValue;
    }

    public String storedValue() {
        return storedValue;
    }

    public boolean isTerminal() {
        return this == CANCELLED;
    }

    public boolean canTransitionTo(TaskStatus target) {
        return target != null && ALLOWED_TRANSITIONS.get(this).contains(target);
    }

    public Set<TaskStatus> allowedTargets() {
        return ALLOWED_TRANSITIONS.get(this);
    }

    public static TaskStatus fromStored(String value) {
        if (value == null) {
            return OPEN;
        }
        for (var status : STATUSES) {
            if (status.storedValue.equalsIgnoreCase(value)) {
                return status;
            }
        }
        return OPEN;
    }

    public static List<String> allStoredValues() {
        return STATUSES.stream().map(TaskStatus::storedValue).toList();
    }
}
