package com.microflow.agent.runtime.domain.model;

import java.util.Map;

/**
 * Typed readers for a connector's non-secret configuration.
 *
 * <p>Config is stored as free-form JSON because the four connector kinds need
 * different fields, but nothing downstream should be doing unchecked casts on
 * it. Each read either returns a usable value or a documented default.
 */
public final class ConnectorSettings {

    public static final String USERNAME = "username";
    public static final String PASSWORD = "password";

    private ConnectorSettings() {
    }

    public static String string(Map<String, Object> config, String key, String fallback) {
        var value = config == null ? null : config.get(key);
        if (value instanceof String text && !text.isBlank()) {
            return text.trim();
        }
        return fallback;
    }

    public static String require(Map<String, Object> config, String key) {
        var value = string(config, key, null);
        if (value == null) {
            throw new IllegalArgumentException("Connector setting '%s' is required".formatted(key));
        }
        return value;
    }

    public static int integer(Map<String, Object> config, String key, int fallback) {
        var value = config == null ? null : config.get(key);
        if (value instanceof Number number) {
            return number.intValue();
        }
        if (value instanceof String text && !text.isBlank()) {
            try {
                return Integer.parseInt(text.trim());
            } catch (NumberFormatException exception) {
                return fallback;
            }
        }
        return fallback;
    }

    public static boolean bool(Map<String, Object> config, String key, boolean fallback) {
        var value = config == null ? null : config.get(key);
        if (value instanceof Boolean flag) {
            return flag;
        }
        if (value instanceof String text && !text.isBlank()) {
            return Boolean.parseBoolean(text.trim());
        }
        return fallback;
    }

    /** Trims a trailing slash so URL joining is predictable. */
    public static String stripTrailingSlash(String url) {
        if (url == null) {
            return null;
        }
        var trimmed = url.trim();
        while (trimmed.endsWith("/")) {
            trimmed = trimmed.substring(0, trimmed.length() - 1);
        }
        return trimmed;
    }
}
