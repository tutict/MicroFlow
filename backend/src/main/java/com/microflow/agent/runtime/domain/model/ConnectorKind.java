package com.microflow.agent.runtime.domain.model;

import java.util.List;
import java.util.Locale;

/**
 * The on-demand connector families MicroFlow supports in the first release.
 *
 * <p>Each kind declares which directions it can carry. A connector instance
 * additionally carries {@code readEnabled}/{@code writeEnabled}, so an IMAP
 * mailbox can be exposed read-only even though CalDAV in the same workspace is
 * writable. Nothing here implies background synchronisation: a kind is only a
 * description of how to reach an external system when a run explicitly asks
 * for it.
 */
public enum ConnectorKind {

    /** Mailbox read access. Never writable: sending lives on SMTP. */
    IMAP("IMAP", true, false),

    /** Outbound mail only. */
    SMTP("SMTP", false, true),

    /** Calendar collections, read and write. */
    CALDAV("CalDAV", true, true),

    /** Generic file collections, read and write. */
    WEBDAV("WebDAV", true, true);

    private final String label;
    private final boolean readCapable;
    private final boolean writeCapable;

    ConnectorKind(String label, boolean readCapable, boolean writeCapable) {
        this.label = label;
        this.readCapable = readCapable;
        this.writeCapable = writeCapable;
    }

    public String label() {
        return label;
    }

    public boolean readCapable() {
        return readCapable;
    }

    public boolean writeCapable() {
        return writeCapable;
    }

    /** Kinds that can carry a read tool. */
    public static List<ConnectorKind> readable() {
        return List.of(values()).stream().filter(ConnectorKind::readCapable).toList();
    }

    /** Strict lookup: an unknown string must not silently become IMAP. */
    public static ConnectorKind parse(String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("connectorKind is required");
        }
        var normalized = value.trim().toUpperCase(Locale.ROOT);
        for (var kind : values()) {
            if (kind.name().equals(normalized)) {
                return kind;
            }
        }
        throw new IllegalArgumentException("Unknown connector kind: " + value);
    }

    public static ConnectorKind parseOrNull(String value) {
        try {
            return parse(value);
        } catch (IllegalArgumentException exception) {
            return null;
        }
    }
}
