package com.microflow.agent.runtime.application;

import com.microflow.agent.runtime.domain.connector.ConnectorProbe;
import com.microflow.agent.runtime.domain.model.AgentConnector;
import com.microflow.agent.runtime.domain.model.ConnectorKind;
import com.microflow.agent.runtime.domain.model.ConnectorSettings;
import com.microflow.agent.runtime.domain.model.ConnectorSharingScope;
import com.microflow.agent.runtime.domain.model.ConnectorStatus;
import com.microflow.agent.runtime.infrastructure.persistence.JdbcConnectorRepository;
import com.microflow.common.error.AccessDeniedException;
import com.microflow.common.error.ResourceNotFoundException;
import com.microflow.workspace.application.service.WorkspaceAccessGuard;
import com.microflow.workspace.domain.model.WorkspaceRole;
import jakarta.enterprise.inject.Instance;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.stream.StreamSupport;
import org.springframework.stereotype.Service;

/**
 * Connector management: create, edit, share, delete and connectivity-test.
 *
 * <p>Three rules are enforced here rather than in the controller, because they
 * are about what may happen to credentials, not about HTTP:
 *
 * <ul>
 *   <li>a credential is personal until its owner explicitly widens the circle,
 *       and widening it beyond {@code PRIVATE} needs a maintainer role;</li>
 *   <li>secrets are write-only: they go in, field names come back;</li>
 *   <li>plain HTTP is refused except for loopback, so a password is never sent
 *       in the clear to a remote host.</li>
 * </ul>
 */
@Service
public class ConnectorService {

    private static final int MAX_NAME_LENGTH = 80;
    private static final int MAX_SHARED_USERS = 200;

    private final JdbcConnectorRepository repository;
    private final WorkspaceAccessGuard accessGuard;
    /**
     * Injected as {@link Instance} rather than {@code List<ConnectorProbe>}:
     * ArC cannot resolve a {@code List} of beans because the SmallRye config
     * producer also claims that type, which fails at build time with an
     * unsatisfied dependency.
     */
    private final Instance<ConnectorProbe> probes;

    public ConnectorService(
            JdbcConnectorRepository repository,
            WorkspaceAccessGuard accessGuard,
            Instance<ConnectorProbe> probes
    ) {
        this.repository = repository;
        this.accessGuard = accessGuard;
        this.probes = probes;
    }

    // ----------------------------------------------------------------- commands

    public AgentConnector create(String userId, String workspaceId, ConnectorCommand command) {
        accessGuard.requireCapability(workspaceId, userId, WorkspaceRole.Capability.CREATE_TASK);
        var kind = ConnectorKind.parse(command.kind());
        var name = requireName(command.name());
        var config = validatedConfig(kind, command.config());
        var secrets = validatedSecrets(command.secrets(), true);
        var scope = ConnectorSharingScope.parse(command.sharingScope());
        var sharedUserIds = validatedSharedUsers(workspaceId, userId, scope, command.sharedUserIds());
        var sharedAgentKeys = normalizedList(command.sharedAgentKeys());
        var directions = directions(kind, command.readEnabled(), command.writeEnabled());
        requireSharePermission(workspaceId, userId, scope);

        return repository.insert(
                workspaceId,
                userId,
                kind,
                name,
                config,
                secrets,
                scope,
                sharedUserIds,
                sharedAgentKeys,
                directions.readEnabled(),
                directions.writeEnabled()
        );
    }

    public AgentConnector update(
            String userId,
            String workspaceId,
            String connectorId,
            ConnectorCommand command
    ) {
        accessGuard.requireCapability(workspaceId, userId, WorkspaceRole.Capability.CREATE_TASK);
        var existing = requireVisible(userId, workspaceId, connectorId);
        requireOwner(existing, userId, "Only the connector owner may change it");

        var kind = command.kind() == null || command.kind().isBlank()
                ? existing.kind()
                : ConnectorKind.parse(command.kind());
        if (kind != existing.kind()) {
            throw new IllegalArgumentException("Changing a connector's kind is not supported; create a new one");
        }
        var name = requireName(command.name() == null ? existing.name() : command.name());
        var config = command.config() == null
                ? existing.config()
                : validatedConfig(kind, command.config());
        var secrets = validatedSecrets(command.secrets(), false);
        var scope = ConnectorSharingScope.parse(
                command.sharingScope() == null ? existing.sharingScope().name() : command.sharingScope());
        var sharedUserIds = validatedSharedUsers(workspaceId, userId, scope, command.sharedUserIds());
        var sharedAgentKeys = command.sharedAgentKeys() == null
                ? existing.sharedAgentKeys()
                : normalizedList(command.sharedAgentKeys());
        var directions = directions(
                kind,
                command.readEnabled() == null ? existing.readEnabled() : command.readEnabled(),
                command.writeEnabled() == null ? existing.writeEnabled() : command.writeEnabled());
        requireSharePermission(workspaceId, userId, scope);

        return repository.update(
                connectorId,
                name,
                config,
                secrets,
                scope,
                sharedUserIds,
                sharedAgentKeys,
                directions.readEnabled(),
                directions.writeEnabled()
        );
    }

    public void delete(String userId, String workspaceId, String connectorId) {
        accessGuard.requireCapability(workspaceId, userId, WorkspaceRole.Capability.CREATE_TASK);
        var existing = requireVisible(userId, workspaceId, connectorId);
        var role = accessGuard.roleOf(workspaceId, userId);
        var workspaceOwner = role != null && role.can(WorkspaceRole.Capability.MANAGE_ROLES);
        if (!workspaceOwner && !existing.ownerUserId().equals(userId)) {
            throw new AccessDeniedException("Only the connector owner may delete it");
        }
        repository.delete(connectorId);
    }

    // ------------------------------------------------------------------ queries

    public List<AgentConnector> list(String userId, String workspaceId) {
        accessGuard.requireMember(workspaceId, userId);
        return repository.listByWorkspace(workspaceId).stream()
                .filter(connector -> connector.visibleTo(userId))
                .toList();
    }

    public AgentConnector requireVisible(String userId, String workspaceId, String connectorId) {
        var connector = repository.find(connectorId)
                .orElseThrow(() -> new ResourceNotFoundException("Connector not found: " + connectorId));
        if (!connector.workspaceId().equals(workspaceId) || !connector.visibleTo(userId)) {
            throw new ResourceNotFoundException("Connector not found: " + connectorId);
        }
        return connector;
    }

    /**
     * Runs the connectivity probe and records the outcome.
     *
     * <p>The probe result is persisted so the settings list can show a truthful
     * last-known state without re-testing on every page load.
     */
    public ConnectorCheck test(String userId, String workspaceId, String connectorId) {
        accessGuard.requireMember(workspaceId, userId);
        var connector = requireVisible(userId, workspaceId, connectorId);
        var credentials = repository.findCredentials(connectorId);
        var probe = StreamSupport.stream(probes.spliterator(), false)
                .filter(candidate -> candidate.supports(connector.kind()))
                .findFirst()
                .orElseThrow(() -> new IllegalStateException(
                        "No probe is registered for " + connector.kind()));
        ConnectorProbe.ProbeOutcome outcome;
        try {
            outcome = probe.test(connector, credentials);
        } catch (RuntimeException exception) {
            outcome = ConnectorProbe.ProbeOutcome.failed(
                    exception.getMessage() == null ? exception.getClass().getSimpleName()
                            : exception.getMessage());
        }
        var status = outcome.reachable() ? ConnectorStatus.ACTIVE : ConnectorStatus.FAILED;
        repository.markChecked(connectorId, status, outcome.reachable() ? null : outcome.detail());
        return new ConnectorCheck(
                connectorId,
                status,
                outcome.detail(),
                repository.find(connectorId).map(AgentConnector::lastCheckedAt).orElse(null)
        );
    }

    // --------------------------------------------------------------- validation

    private Map<String, Object> validatedConfig(ConnectorKind kind, Map<String, Object> raw) {
        var config = raw == null ? new LinkedHashMap<String, Object>() : new LinkedHashMap<>(raw);
        switch (kind) {
            case IMAP, SMTP -> {
                var host = ConnectorSettings.string(config, "host", null);
                if (host == null) {
                    throw new IllegalArgumentException("host is required for " + kind.label());
                }
                var port = ConnectorSettings.integer(config, "port", kind == ConnectorKind.IMAP ? 993 : 587);
                if (port < 1 || port > 65535) {
                    throw new IllegalArgumentException("port must be between 1 and 65535");
                }
                config.put("host", host);
                config.put("port", port);
                config.putIfAbsent("tls", Boolean.TRUE);
                if (kind == ConnectorKind.IMAP) {
                    config.putIfAbsent("mailbox", "INBOX");
                }
            }
            case CALDAV, WEBDAV -> {
                var baseUrl = ConnectorSettings.string(config, "baseUrl", null);
                if (baseUrl == null) {
                    throw new IllegalArgumentException("baseUrl is required for " + kind.label());
                }
                requireSecureUrl(baseUrl);
                config.put("baseUrl", ConnectorSettings.stripTrailingSlash(baseUrl));
            }
        }
        return config;
    }

    /**
     * Refuses to send Basic-auth credentials over plain HTTP to a remote host.
     * Loopback is exempt because the connector test server and local dev
     * instances legitimately run on {@code http://127.0.0.1}.
     */
    private void requireSecureUrl(String url) {
        var lower = url.trim().toLowerCase(Locale.ROOT);
        if (lower.startsWith("https://")) {
            return;
        }
        if (!lower.startsWith("http://")) {
            throw new IllegalArgumentException("baseUrl must be an http(s) URL");
        }
        var host = lower.substring("http://".length());
        var slash = host.indexOf('/');
        if (slash >= 0) {
            host = host.substring(0, slash);
        }
        var colon = host.indexOf(':');
        if (colon >= 0) {
            host = host.substring(0, colon);
        }
        if (!host.equals("localhost") && !host.equals("127.0.0.1") && !host.equals("[::1]")) {
            throw new IllegalArgumentException(
                    "baseUrl must use https; plain http is only allowed for loopback addresses");
        }
    }

    private Map<String, String> validatedSecrets(Map<String, String> raw, boolean required) {
        if (raw == null) {
            if (required) {
                throw new IllegalArgumentException("Credentials are required");
            }
            return null;
        }
        var secrets = new LinkedHashMap<String, String>();
        raw.forEach((key, value) -> {
            if (key != null && !key.isBlank() && value != null && !value.isEmpty()) {
                secrets.put(key.trim(), value);
            }
        });
        if (!raw.isEmpty() && secrets.isEmpty()) {
            throw new IllegalArgumentException("Credential fields must contain non-empty strings");
        }
        if (required && !secrets.containsKey(ConnectorSettings.PASSWORD)) {
            throw new IllegalArgumentException("A password or app password is required");
        }
        return Map.copyOf(secrets);
    }

    private List<String> validatedSharedUsers(
            String workspaceId,
            String userId,
            ConnectorSharingScope scope,
            List<String> requested
    ) {
        if (scope != ConnectorSharingScope.SELECTED) {
            return List.of();
        }
        var candidates = normalizedList(requested).stream()
                .filter(candidate -> !candidate.equals(userId))
                .toList();
        if (candidates.isEmpty()) {
            throw new IllegalArgumentException("Select at least one person to share with");
        }
        if (candidates.size() > MAX_SHARED_USERS) {
            throw new IllegalArgumentException("Too many recipients on the share list");
        }
        var accepted = new ArrayList<String>();
        for (var candidate : candidates) {
            if (!accessGuard.isMember(workspaceId, candidate)) {
                throw new IllegalArgumentException(
                        "User " + candidate + " is not a member of this workspace");
            }
            accepted.add(candidate);
        }
        return List.copyOf(accepted);
    }

    private void requireSharePermission(
            String workspaceId,
            String userId,
            ConnectorSharingScope scope
    ) {
        if (scope == ConnectorSharingScope.PRIVATE) {
            return;
        }
        var role = accessGuard.roleOf(workspaceId, userId);
        if (role == null || !role.outranks(WorkspaceRole.OPERATOR)) {
            throw new AccessDeniedException(
                    "Sharing a connector beyond yourself requires a maintainer role");
        }
    }

    private void requireOwner(AgentConnector connector, String userId, String message) {
        if (!connector.ownerUserId().equals(userId)) {
            throw new AccessDeniedException(message);
        }
    }

    /**
     * Resolves the read/write flags against what the kind can actually do.
     *
     * <p>An IMAP connector cannot be made writable by a stray request flag; the
     * kind wins, which keeps "send mail" from ever being routed through a
     * read-only mailbox connection.
     */
    private Direction directions(ConnectorKind kind, Boolean readEnabled, Boolean writeEnabled) {
        var read = readEnabled == null ? kind.readCapable() : readEnabled;
        var write = writeEnabled == null ? kind.writeCapable() : writeEnabled;
        if (read && !kind.readCapable()) {
            throw new IllegalArgumentException(kind.label() + " cannot be used for reading");
        }
        if (write && !kind.writeCapable()) {
            throw new IllegalArgumentException(kind.label() + " cannot be used for writing");
        }
        if (!read && !write) {
            throw new IllegalArgumentException("Enable at least one direction");
        }
        return new Direction(read, write);
    }

    private String requireName(String name) {
        var trimmed = name == null ? "" : name.trim();
        if (trimmed.isEmpty()) {
            throw new IllegalArgumentException("A connector name is required");
        }
        return trimmed.length() <= MAX_NAME_LENGTH ? trimmed : trimmed.substring(0, MAX_NAME_LENGTH);
    }

    private List<String> normalizedList(List<String> values) {
        if (values == null) {
            return List.of();
        }
        return values.stream()
                .filter(value -> value != null && !value.isBlank())
                .map(String::trim)
                .distinct()
                .toList();
    }

    private record Direction(boolean readEnabled, boolean writeEnabled) {
    }

    /**
     * Create/update payload.
     *
     * <p>{@code secrets} is {@code null} on update when the caller only wants to
     * rename or reshare, so an unchanged password never has to travel again.
     */
    public record ConnectorCommand(
            String kind,
            String name,
            Map<String, Object> config,
            Map<String, String> secrets,
            String sharingScope,
            List<String> sharedUserIds,
            List<String> sharedAgentKeys,
            Boolean readEnabled,
            Boolean writeEnabled
    ) {
    }

    public record ConnectorCheck(
            String connectorId,
            ConnectorStatus status,
            String detail,
            String checkedAt
    ) {
    }
}
