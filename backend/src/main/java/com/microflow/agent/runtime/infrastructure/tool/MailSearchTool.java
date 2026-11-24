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
import com.microflow.agent.runtime.infrastructure.connector.mail.ImapMailClient;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.stereotype.Component;

/**
 * Reads message headers from the run initiator's mailbox.
 *
 * <p>Read-only and therefore automatic: it touches the outside world but changes
 * nothing, and the user already sees the resulting snippets in the run card.
 * Only headers are fetched, so message bodies never enter the context window
 * without a separate, explicit step.
 */
@Component
public class MailSearchTool implements AgentTool {

    private final ConnectorResolver resolver;
    private final ImapMailClient client;

    public MailSearchTool(ConnectorResolver resolver) {
        this.resolver = resolver;
        this.client = new ImapMailClient();
    }

    @Override
    public ToolDescriptor descriptor() {
        return new ToolDescriptor(
                "mail.search",
                "Search mail headers",
                "Search the connected mailbox and return matching message headers "
                        + "(sender, subject, date). Bodies are not returned.",
                Map.of(
                        "type", "object",
                        "properties", Map.of(
                                "query", Map.of(
                                        "type", "string",
                                        "description", "IMAP search criteria, for example "
                                                + "'UNSEEN' or 'SUBJECT invoice'. Defaults to ALL."),
                                "limit", Map.of(
                                        "type", "integer",
                                        "description", "How many recent matches to return (1-20)")
                        )
                ),
                ToolPolicy.Permission.AUTO,
                ToolPolicy.Risk.READ_ONLY,
                true,
                ConnectorKind.IMAP.name()
        );
    }

    @Override
    public ToolResult invoke(ToolContext context, Map<String, Object> input) {
        var resolved = resolver.resolve(
                context.workspaceId(),
                context.initiatorUserId(),
                context.agentKey(),
                ConnectorKind.IMAP,
                false);
        if (resolved.isEmpty()) {
            return ToolResult.failed("No IMAP connector is available to this run");
        }
        var connector = resolved.get().connector();
        var credentials = resolved.get().credentials();
        var config = connector.config();
        var limit = ToolInputs.optionalInt(input, "limit", 10, 1, 20);
        var query = ToolInputs.optionalString(input, "query");
        try {
            var headers = client.search(
                    ConnectorSettings.require(config, "host"),
                    ConnectorSettings.integer(config, "port", 993),
                    ConnectorSettings.bool(config, "tls", true),
                    ConnectorSettings.bool(config, "startTls", false),
                    credentials.get(ConnectorSettings.USERNAME),
                    credentials.get(ConnectorSettings.PASSWORD),
                    ConnectorSettings.string(config, "mailbox", "INBOX"),
                    query,
                    limit
            );
            var messages = new java.util.ArrayList<Map<String, Object>>();
            for (var header : headers) {
                var row = new LinkedHashMap<String, Object>();
                row.put("from", header.from());
                row.put("subject", header.subject());
                row.put("date", header.date());
                messages.add(row);
            }
            var summary = headers.isEmpty()
                    ? "No messages matched the search."
                    : "%d message(s) matched: %s".formatted(
                            headers.size(),
                            String.join("; ", headers.stream().map(ImapMailClient.MailHeader::summary)
                                    .limit(3).toList()));
            return ToolResult.ok(Map.of("messages", messages, "count", messages.size()), summary);
        } catch (RuntimeException exception) {
            return ToolResult.failed(message(exception));
        }
    }

    private static String message(RuntimeException exception) {
        var detail = exception.getMessage();
        return detail == null || detail.isBlank() ? exception.getClass().getSimpleName() : detail;
    }
}
