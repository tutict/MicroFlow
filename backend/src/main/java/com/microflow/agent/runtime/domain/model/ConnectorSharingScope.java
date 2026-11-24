package com.microflow.agent.runtime.domain.model;

import java.util.Locale;

/**
 * Who may use a connector's credentials.
 *
 * <p>Credentials are personal by default. Sharing is an explicit, recorded
 * widening of that circle, never something inferred from workspace membership.
 */
public enum ConnectorSharingScope {

    /** Only the owner. */
    PRIVATE,

    /** Every workspace member. */
    WORKSPACE,

    /** The owner plus {@code sharedUserIds}. */
    SELECTED;

    public static ConnectorSharingScope parse(String value) {
        if (value == null || value.isBlank()) {
            return PRIVATE;
        }
        var normalized = value.trim().toUpperCase(Locale.ROOT);
        for (var scope : values()) {
            if (scope.name().equals(normalized)) {
                return scope;
            }
        }
        throw new IllegalArgumentException("Unknown sharing scope: " + value);
    }
}
