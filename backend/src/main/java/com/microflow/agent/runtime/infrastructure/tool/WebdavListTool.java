package com.microflow.agent.runtime.infrastructure.tool;

import com.microflow.agent.runtime.application.ConnectorResolver;
import com.microflow.agent.runtime.domain.model.ConnectorKind;
import com.microflow.agent.runtime.domain.model.ConnectorSettings;
import com.microflow.agent.runtime.domain.model.ToolDescriptor;
import com.microflow.agent.runtime.domain.model.ToolPolicy;
import com.microflow.agent.runtime.domain.tool.AgentTool;
import com.microflow.agent.runtime.domain.tool.ToolContext;
import com.microflow.agent.runtime.domain.tool.ToolInputs;
import com.microflow.agent.runtime.domain.tool.ToolResult;
import com.microflow.agent.runtime.infrastructure.connector.ConnectorHttpClient;
import java.util.ArrayList;
import java.util.Map;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

/**
 * Lists one WebDAV collection.
 *
 * <p>Depth is fixed at 1: a recursive crawl of someone's drive is exactly the
 * background synchronisation this product promises not to do.
 */
@Component
public class WebdavListTool implements AgentTool {

    private static final Pattern HREF =
            Pattern.compile("<(?:[A-Za-z0-9]+:)?href[^>]*>([^<]*)</(?:[A-Za-z0-9]+:)?href>");

    private final ConnectorResolver resolver;
    private final ConnectorHttpClient httpClient;

    public WebdavListTool(ConnectorResolver resolver, ConnectorHttpClient httpClient) {
        this.resolver = resolver;
        this.httpClient = httpClient;
    }

    @Override
    public ToolDescriptor descriptor() {
        return new ToolDescriptor(
                "webdav.list",
                "List a WebDAV folder",
                "List the direct children of one WebDAV collection. "
                        + "Does not recurse and does not download file contents.",
                Map.of(
                        "type", "object",
                        "properties", Map.of(
                                "path", Map.of(
                                        "type", "string",
                                        "description", "Collection path relative to the connector base URL, "
                                                + "for example 'notes/2026'. Defaults to the root.")
                        )
                ),
                ToolPolicy.Permission.AUTO,
                ToolPolicy.Risk.READ_ONLY,
                true,
                ConnectorKind.WEBDAV.name()
        );
    }

    @Override
    public ToolResult invoke(ToolContext context, Map<String, Object> input) {
        var resolved = resolver.resolve(
                context.workspaceId(),
                context.initiatorUserId(),
                context.agentKey(),
                ConnectorKind.WEBDAV,
                false);
        if (resolved.isEmpty()) {
            return ToolResult.failed("No WebDAV connector is available to this run");
        }
        var connector = resolved.get().connector();
        var credentials = resolved.get().credentials();
        var baseUrl = ConnectorSettings.string(connector.config(), "baseUrl", null);
        if (baseUrl == null) {
            return ToolResult.failed("This WebDAV connector has no baseUrl configured");
        }
        var path = ToolInputs.optionalString(input, "path");
        var url = ConnectorSettings.stripTrailingSlash(baseUrl)
                + (path == null || path.isBlank() ? "" : "/" + stripLeadingSlash(path)) + "/";
        try {
            var response = httpClient.propfind(
                    url,
                    credentials.get(ConnectorSettings.USERNAME),
                    credentials.get(ConnectorSettings.PASSWORD),
                    1);
            if (!response.multiStatus() && !response.successful()) {
                if (!response.authorized()) {
                    return ToolResult.failed("WebDAV rejected the credentials (%d)".formatted(
                            response.status()));
                }
                return ToolResult.failed("WebDAV answered %d".formatted(response.status()));
            }
            var entries = new ArrayList<String>();
            var matcher = HREF.matcher(response.body() == null ? "" : response.body());
            while (matcher.find()) {
                var href = matcher.group(1).trim();
                if (!href.isEmpty() && !entries.contains(href)) {
                    entries.add(href);
                }
            }
            return ToolResult.ok(
                    Map.of("entries", entries, "count", entries.size()),
                    entries.isEmpty()
                            ? "The collection is empty."
                            : "%d entr(ies) in %s".formatted(entries.size(), url));
        } catch (RuntimeException exception) {
            var detail = exception.getMessage();
            return ToolResult.failed(detail == null || detail.isBlank()
                    ? exception.getClass().getSimpleName()
                    : detail);
        }
    }

    private static String stripLeadingSlash(String value) {
        var trimmed = value.trim();
        while (trimmed.startsWith("/")) {
            trimmed = trimmed.substring(1);
        }
        return trimmed;
    }
}
