package com.microflow.workspace.domain.model;

import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Workspace member roles and the capabilities each role grants.
 *
 * <p>The baseline schema stored only the free-form strings {@code OWNER} and
 * {@code MEMBER}, and every read path compared the raw string. This enum makes
 * the role set explicit and turns it into a capability matrix, so a small
 * three-person team can express a decision maker, an executor and an observer
 * without any endpoint re-checking ownership by hand.
 *
 * <p>{@link #fromStored(String)} deliberately keeps accepting the legacy
 * {@code MEMBER} value and maps it to {@link #OPERATOR}, so existing databases
 * and seed data keep their meaning after the migration.
 */
public enum WorkspaceRole {

    OWNER("OWNER", 0),
    MAINTAINER("MAINTAINER", 1),
    OPERATOR("OPERATOR", 2),
    VIEWER("VIEWER", 3);

    private static final List<WorkspaceRole> ROLES = List.of(values());

    private static final Map<WorkspaceRole, Set<Capability>> GRANTS = Map.of(
            OWNER,
            Set.of(
                    Capability.VIEW,
                    Capability.CREATE_TASK,
                    Capability.ADVANCE_ANY_TASK,
                    Capability.CREATE_PROJECT,
                    Capability.ASSIGN_ANY_TASK,
                    Capability.MANAGE_ROLES),
            MAINTAINER,
            Set.of(
                    Capability.VIEW,
                    Capability.CREATE_TASK,
                    Capability.ADVANCE_ANY_TASK,
                    Capability.CREATE_PROJECT,
                    Capability.ASSIGN_ANY_TASK),
            OPERATOR,
            Set.of(Capability.VIEW, Capability.CREATE_TASK),
            VIEWER,
            Set.of(Capability.VIEW)
    );

    private final String storedValue;
    private final int sortOrder;

    WorkspaceRole(String storedValue, int sortOrder) {
        this.storedValue = storedValue;
        this.sortOrder = sortOrder;
    }

    public String storedValue() {
        return storedValue;
    }

    public int sortOrder() {
        return sortOrder;
    }

    public boolean can(Capability capability) {
        return GRANTS.get(this).contains(capability);
    }

    public Set<Capability> capabilities() {
        return GRANTS.get(this);
    }

    /**
     * Whether this role may change another member's role.
     *
     * <p>Strict outranking would stop an owner from demoting a second owner, which
     * would make the last-owner guard unreachable in the only case it protects.
     * Equal-tier management is therefore allowed; the service layer separately
     * forbids self-demotion.
     */
    public boolean canManageRole(WorkspaceRole other) {
        return can(Capability.MANAGE_ROLES) && (outranks(other) || this == other);
    }

    public boolean outranks(WorkspaceRole other) {
        return this.sortOrder < other.sortOrder;
    }

    public static WorkspaceRole fromStored(String value) {
        if (value == null || value.isBlank()) {
            return OPERATOR;
        }
        var normalized = value.trim();
        if ("MEMBER".equalsIgnoreCase(normalized)) {
            return OPERATOR;
        }
        var parsed = parseRequested(normalized);
        return parsed == null ? OPERATOR : parsed;
    }

    /**
     * Strict lookup for user-supplied input. Returns {@code null} for anything
     * outside the known role set instead of silently downgrading to
     * {@link #OPERATOR}, so a typo in an administrative request cannot hand out
     * write capability by accident.
     */
    public static WorkspaceRole parseRequested(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        var normalized = value.trim();
        for (var role : ROLES) {
            if (role.storedValue.equalsIgnoreCase(normalized)) {
                return role;
            }
        }
        return null;
    }

    public static List<String> allStoredValues() {
        return ROLES.stream().map(WorkspaceRole::storedValue).toList();
    }

    /** The capability set a role grants. */
    public enum Capability {
        /** Read workspace-scoped data. */
        VIEW,
        /** Create tasks. */
        CREATE_TASK,
        /** Change the status of any task, not only self-created or self-assigned ones. */
        ADVANCE_ANY_TASK,
        /** Create and close task projects. */
        CREATE_PROJECT,
        /** Assign any task to any workspace member. */
        ASSIGN_ANY_TASK,
        /** Change member roles. */
        MANAGE_ROLES
    }
}
