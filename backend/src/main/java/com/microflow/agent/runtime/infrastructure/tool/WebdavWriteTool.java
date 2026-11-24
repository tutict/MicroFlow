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
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.stereotype.Component;

/**
 * Writes one text file through the initiator's WebDAV connector.
 *
 * <p>Approval-gated because it can overwrite a real file. {@code PUT} to a fixed
 * path is idempotent at the protocol level. A missing response still leaves the
 * write outcome unknown and requires verification before another attempt.
 */
@Component
public class WebdavWriteTool implements AgentTool {

    private final ConnectorResolver resolver;
    private final ConnectorHttpClient httpClient;

    public WebdavWriteTool(ConnectorResolver resolver, ConnectorHttpClient httpClient) {
        this.resolver = resolver;
        this.httpClient = httpClient;
    }

    @Override
    public ToolDescriptor descriptor() {
        return new ToolDescriptor(
                "webdav.write",
                "Write a WebDAV file",
                "Create or overwrite one text file in the connected WebDAV space. "
                        + "Requires human approval; the previous content is replaced.",
                Map.of(
                        "type", "object",
                        "properties", Map.of(
                                "path", Map.of(
                                        "type", "string",
                                        "description", "File path relative to the connector base URL"),
                                "content", Map.of("type", "string")
                        ),
                        "required", java.util.List.of("path", "content")
                ),
                ToolPolicy.Permission.APPROVAL,
                ToolPolicy.Risk.EXTERNAL_WRITE,
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
                true);
        if (resolved.isEmpty()) {
            return ToolResult.failed("No WebDAV connector is available to this run");
        }
        var connector = resolved.get().connector();
        var credentials = resolved.get().credentials();
        var baseUrl = ConnectorSettings.string(connector.config(), "baseUrl", null);
        if (baseUrl == null) {
            return ToolResult.failed("This WebDAV connector has no baseUrl configured");
        }
        String content;
        String url;
        try {
            var path = ToolInputs.requiredString(input, "path");
            content = ToolInputs.requiredString(input, "content");
            url = ConnectorSettings.stripTrailingSlash(baseUrl) + "/" + stripLeadingSlash(path);
        } catch (RuntimeException exception) {
            return ToolResult.failed(describe(exception));
        }
        try {
            var response = httpClient.put(
                    url,
                    credentials.get(ConnectorSettings.USERNAME),
                    credentials.get(ConnectorSettings.PASSWORD),
                    "text/plain; charset=utf-8",
                    content);
            if (response.successful()) {
                var output = new LinkedHashMap<String, Object>();
                output.put("href", url);
                output.put("bytes", content.getBytes(StandardCharsets.UTF_8).length);
                return ToolResult.ok(output, "Wrote %s.".formatted(url));
            }
            if (!response.authorized()) {
                return ToolResult.failed("WebDAV rejected the credentials (%d)".formatted(
                        response.status()));
            }
            return ToolResult.failed("WebDAV answered %d".formatted(response.status()));
        } catch (IllegalArgumentException exception) {
            return ToolResult.failed(describe(exception));
        } catch (RuntimeException exception) {
            return ToolResult.unknown("WebDAV PUT outcome is unknown: " + describe(exception));
        }
    }

    private static String describe(RuntimeException exception) {
        var detail = exception.getMessage();
        return detail == null || detail.isBlank() ? exception.getClass().getSimpleName() : detail;
    }

    private static String stripLeadingSlash(String value) {
        var trimmed = value.trim();
        while (trimmed.startsWith("/")) {
            trimmed = trimmed.substring(1);
        }
        return trimmed;
    }
}
