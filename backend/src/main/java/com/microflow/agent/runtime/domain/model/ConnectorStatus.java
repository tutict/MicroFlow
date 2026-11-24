package com.microflow.agent.runtime.domain.model;

/** Result of the last connectivity check, or no check yet. */
public enum ConnectorStatus {
    /** Created or edited, never tested. */
    UNVERIFIED,
    /** Last check reached the remote system. */
    ACTIVE,
    /** Last check failed; {@code lastError} says why. */
    FAILED
}
