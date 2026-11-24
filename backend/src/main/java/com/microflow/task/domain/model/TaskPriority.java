package com.microflow.task.domain.model;

public enum TaskPriority {

    LOW("LOW"),
    NORMAL("NORMAL"),
    HIGH("HIGH"),
    URGENT("URGENT");

    private final String storedValue;

    TaskPriority(String storedValue) {
        this.storedValue = storedValue;
    }

    public String storedValue() {
        return storedValue;
    }

    public static TaskPriority fromStored(String value) {
        if (value == null) {
            return NORMAL;
        }
        for (var priority : values()) {
            if (priority.storedValue.equalsIgnoreCase(value)) {
                return priority;
            }
        }
        return NORMAL;
    }
}
