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
import com.microflow.agent.runtime.infrastructure.connector.mail.SmtpMailClient;
import java.time.Clock;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Component;

/**
 * Sends one email through the initiator's SMTP connector.
 *
 * <p>Approval-gated and explicitly non-idempotent: once {@code DATA} is
 * accepted, a retry could deliver the message twice. A failure after that point
 * therefore returns {@link ToolResult#unknown(String)} and the runtime stops
 * rather than replaying it.
 */
@Component
public class MailSendTool implements AgentTool {

    private final ConnectorResolver resolver;
    private final SmtpMailClient client;

    public MailSendTool(ConnectorResolver resolver, Clock clock) {
        this.resolver = resolver;
        this.client = new SmtpMailClient(clock);
    }

    @Override
    public ToolDescriptor descriptor() {
        return new ToolDescriptor(
                "mail.send",
                "Send an email",
                "Send one plain-text email from the connected account. "
                        + "Requires human approval; delivery cannot be undone.",
                Map.of(
                        "type", "object",
                        "properties", Map.of(
                                "to", Map.of(
                                        "type", "array",
                                        "items", Map.of("type", "string"),
                                        "description", "Recipient addresses"),
                                "subject", Map.of("type", "string"),
                                "body", Map.of("type", "string"),
                                "cc", Map.of(
                                        "type", "array",
                                        "items", Map.of("type", "string"),
                                        "description", "Optional carbon copy addresses")
                        ),
                        "required", List.of("to", "subject", "body")
                ),
                ToolPolicy.Permission.APPROVAL,
                ToolPolicy.Risk.EXTERNAL_WRITE,
                false,
                ConnectorKind.SMTP.name()
        );
    }

    @Override
    public ToolResult invoke(ToolContext context, Map<String, Object> input) {
        var resolved = resolver.resolve(
                context.workspaceId(),
                context.initiatorUserId(),
                context.agentKey(),
                ConnectorKind.SMTP,
                true);
        if (resolved.isEmpty()) {
            return ToolResult.failed("No SMTP connector is available to this run");
        }
        var connector = resolved.get().connector();
        var credentials = resolved.get().credentials();
        var config = connector.config();
        var recipients = addresses(input, "to");
        if (recipients.isEmpty()) {
            return ToolResult.failed("At least one recipient is required");
        }
        recipients.addAll(addresses(input, "cc"));
        var subject = ToolInputs.requiredString(input, "subject");
        var body = ToolInputs.requiredString(input, "body");
        var from = ConnectorSettings.string(config, "fromAddress",
                credentials.get(ConnectorSettings.USERNAME));
        if (from == null || from.isBlank()) {
            return ToolResult.failed("This SMTP connector has no from address configured");
        }
        try {
            var result = client.send(
                    ConnectorSettings.require(config, "host"),
                    ConnectorSettings.integer(config, "port", 587),
                    ConnectorSettings.bool(config, "tls", true),
                    credentials.get(ConnectorSettings.USERNAME),
                    credentials.get(ConnectorSettings.PASSWORD),
                    from,
                    recipients,
                    subject,
                    body
            );
            return ToolResult.ok(
                    Map.of(
                            "recipientCount", result.recipientCount(),
                            "from", from,
                            "subject", subject
                    ),
                    "Sent \"%s\" to %d recipient(s).".formatted(subject, result.recipientCount())
            );
        } catch (SmtpMailClient.UncertainDeliveryException exception) {
            return ToolResult.unknown(exception.getMessage());
        } catch (RuntimeException exception) {
            return ToolResult.failed(message(exception));
        }
    }

    private static List<String> addresses(Map<String, Object> input, String key) {
        var value = input == null ? null : input.get(key);
        var addresses = new ArrayList<String>();
        if (value instanceof List<?> list) {
            for (var item : list) {
                if (item instanceof String text && !text.isBlank()) {
                    addresses.add(text.trim());
                }
            }
        } else if (value instanceof String text && !text.isBlank()) {
            for (var part : text.split(",")) {
                if (!part.isBlank()) {
                    addresses.add(part.trim());
                }
            }
        }
        return addresses;
    }

    private static String message(RuntimeException exception) {
        var detail = exception.getMessage();
        return detail == null || detail.isBlank() ? exception.getClass().getSimpleName() : detail;
    }
}
