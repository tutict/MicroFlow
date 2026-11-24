package com.microflow.agent.runtime.domain.tool;

import java.util.Map;

/** Small, strict readers for model-supplied tool arguments. */
public final class ToolInputs {

    private ToolInputs() {
    }

    public static String requiredString(Map<String, Object> input, String key) {
        var value = input == null ? null : input.get(key);
        if (!(value instanceof String text) || text.isBlank()) {
            throw new IllegalArgumentException("Tool input '%s' is required".formatted(key));
        }
        return text.trim();
    }

    public static String optionalString(Map<String, Object> input, String key) {
        var value = input == null ? null : input.get(key);
        return value instanceof String text ? text.trim() : null;
    }

    public static int optionalInt(Map<String, Object> input, String key, int fallback, int min, int max) {
        var value = input == null ? null : input.get(key);
        var parsed = value instanceof Number number ? number.intValue() : fallback;
        return Math.max(min, Math.min(parsed, max));
    }
}
