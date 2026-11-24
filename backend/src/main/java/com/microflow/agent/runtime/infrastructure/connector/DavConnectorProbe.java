package com.microflow.agent.runtime.infrastructure.connector;

import com.microflow.agent.runtime.domain.connector.ConnectorProbe;
import com.microflow.agent.runtime.domain.model.AgentConnector;
import com.microflow.agent.runtime.domain.model.ConnectorKind;
import com.microflow.agent.runtime.domain.model.ConnectorSettings;
import java.util.Map;
import org.springframework.stereotype.Component;

/**
 * Reachability check for CalDAV and WebDAV.
 *
 * <p>A {@code PROPFIND} with {@code Depth: 0} is the cheapest honest request in
 * WebDAV: it asks the server to describe one resource, so a 207 proves the URL,
 * the TLS chain and the credentials all work, without listing anyone's files.
 */
@Component
public class DavConnectorProbe implements ConnectorProbe {

    private final ConnectorHttpClient httpClient;

    public DavConnectorProbe(ConnectorHttpClient httpClient) {
        this.httpClient = httpClient;
    }

    @Override
    public boolean supports(ConnectorKind kind) {
        return kind == ConnectorKind.CALDAV || kind == ConnectorKind.WEBDAV;
    }

    @Override
    public ProbeOutcome test(AgentConnector connector, Map<String, String> credentials) {
        var baseUrl = ConnectorSettings.string(connector.config(), "baseUrl", null);
        if (baseUrl == null) {
            return ProbeOutcome.failed("baseUrl is not configured");
        }
        try {
            var response = httpClient.propfind(
                    ConnectorSettings.stripTrailingSlash(baseUrl),
                    credentials.get(ConnectorSettings.USERNAME),
                    credentials.get(ConnectorSettings.PASSWORD),
                    0
            );
            if (response.multiStatus() || response.successful()) {
                return ProbeOutcome.ok(
                        "%s answered %d".formatted(connector.kind().label(), response.status()));
            }
            if (!response.authorized()) {
                return ProbeOutcome.failed("Credentials were rejected (%d)".formatted(response.status()));
            }
            return ProbeOutcome.failed("Server answered %d".formatted(response.status()));
        } catch (RuntimeException exception) {
            return ProbeOutcome.failed(message(exception));
        }
    }

    private static String message(RuntimeException exception) {
        var detail = exception.getMessage();
        return detail == null || detail.isBlank() ? exception.getClass().getSimpleName() : detail;
    }
}
