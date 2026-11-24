package com.microflow.agent.runtime.application;

import com.microflow.agent.runtime.domain.model.AgentConnector;
import com.microflow.agent.runtime.domain.model.ConnectorKind;
import com.microflow.agent.runtime.infrastructure.persistence.JdbcConnectorRepository;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.springframework.stereotype.Service;

/**
 * Picks the connector a tool call is allowed to use, and hands back its
 * credentials.
 *
 * <p>Resolution order matters: the run initiator's own connector wins over a
 * shared one, so a shared mailbox never silently becomes the default for
 * someone who configured their own. Credentials returned here are for immediate
 * use by the tool and must never be logged or returned to the model.
 */
@Service
public class ConnectorResolver {

    private final JdbcConnectorRepository repository;

    public ConnectorResolver(JdbcConnectorRepository repository) {
        this.repository = repository;
    }

    public Optional<Resolved> resolve(
            String workspaceId,
            String userId,
            String agentKey,
            ConnectorKind kind,
            boolean requireWrite
    ) {
        return candidates(workspaceId, userId, agentKey, kind, requireWrite)
                .stream()
                .findFirst()
                .map(connector -> new Resolved(connector, repository.findCredentials(connector.id())));
    }

    /**
     * Kinds the runtime may advertise to the model on this run.
     *
     * <p>Filtering the tool catalog matters: offering a tool whose connector is
     * absent invites the model to call it, and a run that fails on a tool the
     * user never enabled looks like a bug rather than a configuration gap.
     */
    public Set<ConnectorKind> availableKinds(String workspaceId, String userId, String agentKey) {
        var kinds = new LinkedHashSet<ConnectorKind>();
        for (var connector : visible(workspaceId, userId, agentKey)) {
            if (connector.readEnabled() && connector.kind().readCapable()) {
                kinds.add(connector.kind());
            }
            if (connector.writeEnabled() && connector.kind().writeCapable()) {
                kinds.add(connector.kind());
            }
        }
        return kinds;
    }

    /** Tests the requested direction without loading or decrypting connector credentials. */
    public boolean isAvailable(String workspaceId, String userId, String agentKey,
                               ConnectorKind kind, boolean requireWrite) {
        return !candidates(workspaceId, userId, agentKey, kind, requireWrite).isEmpty();
    }

    private List<AgentConnector> candidates(
            String workspaceId,
            String userId,
            String agentKey,
            ConnectorKind kind,
            boolean requireWrite
    ) {
        return visible(workspaceId, userId, agentKey).stream()
                .filter(connector -> connector.kind() == kind)
                .filter(connector -> requireWrite
                        ? connector.writeAllowedFor(agentKey)
                        : connector.readAllowedFor(agentKey))
                .toList();
    }

    private List<AgentConnector> visible(String workspaceId, String userId, String agentKey) {
        return repository.listByWorkspace(workspaceId).stream()
                .filter(connector -> connector.visibleTo(userId) && connector.allowsAgent(agentKey))
                .sorted(Comparator
                        .comparing((AgentConnector connector) -> !connector.ownerUserId().equals(userId))
                        .thenComparing(AgentConnector::name))
                .toList();
    }

    /** A connector plus the plaintext credentials needed for one call. */
    public record Resolved(AgentConnector connector, java.util.Map<String, String> credentials) {
    }
}
