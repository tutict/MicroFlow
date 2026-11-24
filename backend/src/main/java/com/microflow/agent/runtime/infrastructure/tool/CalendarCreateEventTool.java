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
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Component;

/**
 * Writes one event into the initiator's CalDAV calendar.
 *
 * <p>Approval-gated because it lands on someone's real calendar. It is
 * idempotent for the same persisted approval: its UID and {@code PUT} target
 * remain stable. An uncertain outcome still requires manual verification;
 * a new approval in a later attempt represents a different operation.
 */
@Component
public class CalendarCreateEventTool implements AgentTool {

    private static final DateTimeFormatter ICS_UTC =
            DateTimeFormatter.ofPattern("uuuuMMdd'T'HHmmss'Z'").withZone(ZoneOffset.UTC);

    private final ConnectorResolver resolver;
    private final ConnectorHttpClient httpClient;

    public CalendarCreateEventTool(ConnectorResolver resolver, ConnectorHttpClient httpClient) {
        this.resolver = resolver;
        this.httpClient = httpClient;
    }

    @Override
    public ToolDescriptor descriptor() {
        return new ToolDescriptor(
                "calendar.create_event",
                "Create a calendar event",
                "Create one event in the connected calendar. "
                        + "Requires human approval; attendees are not invited automatically.",
                Map.of(
                        "type", "object",
                        "properties", Map.of(
                                "summary", Map.of("type", "string"),
                                "start", Map.of(
                                        "type", "string",
                                        "description", "ISO-8601 start, for example 2026-10-01T09:00:00Z"),
                                "end", Map.of(
                                        "type", "string",
                                        "description", "ISO-8601 end; defaults to one hour after start"),
                                "description", Map.of("type", "string"),
                                "location", Map.of("type", "string")
                        ),
                        "required", java.util.List.of("summary", "start")
                ),
                ToolPolicy.Permission.APPROVAL,
                ToolPolicy.Risk.EXTERNAL_WRITE,
                true,
                ConnectorKind.CALDAV.name()
        );
    }

    @Override
    public ToolResult invoke(ToolContext context, Map<String, Object> input) {
        if (context.approvalId() == null || context.approvalId().isBlank()) {
            return ToolResult.failed("Calendar creation requires a persisted approval");
        }
        var resolved = resolver.resolve(
                context.workspaceId(),
                context.initiatorUserId(),
                context.agentKey(),
                ConnectorKind.CALDAV,
                true);
        if (resolved.isEmpty()) {
            return ToolResult.failed("No CalDAV connector is available to this run");
        }
        var connector = resolved.get().connector();
        var credentials = resolved.get().credentials();
        var baseUrl = ConnectorSettings.string(connector.config(), "baseUrl", null);
        if (baseUrl == null) {
            return ToolResult.failed("This CalDAV connector has no baseUrl configured");
        }
        String summary;
        Instant start;
        Instant end;
        String uid;
        String url;
        String calendar;
        try {
            summary = ToolInputs.requiredString(input, "summary");
            start = instantOf(ToolInputs.requiredString(input, "start"));
            var rawEnd = ToolInputs.optionalString(input, "end");
            end = rawEnd == null ? start.plusSeconds(3600) : instantOf(rawEnd);
            if (!end.isAfter(start)) {
                return ToolResult.failed("end must be after start");
            }
            uid = "microflow-" + UUID.nameUUIDFromBytes(
                    ("calendar.create_event:" + context.approvalId()).getBytes(StandardCharsets.UTF_8))
                    + "@microflow.local";
            url = ConnectorSettings.stripTrailingSlash(baseUrl) + "/" + uid + ".ics";
            calendar = renderEvent(uid, summary, start, end,
                    ToolInputs.optionalString(input, "description"),
                    ToolInputs.optionalString(input, "location"));
        } catch (RuntimeException exception) {
            return ToolResult.failed("Invalid calendar event input: " + describe(exception));
        }

        try {
            var response = httpClient.put(
                    url,
                    credentials.get(ConnectorSettings.USERNAME),
                    credentials.get(ConnectorSettings.PASSWORD),
                    "text/calendar; charset=utf-8",
                    calendar);
            if (response.successful() || response.multiStatus()) {
                var output = new LinkedHashMap<String, Object>();
                output.put("uid", uid);
                output.put("summary", summary);
                output.put("start", start.toString());
                output.put("end", end.toString());
                output.put("href", url);
                return ToolResult.ok(output,
                        "Created \"%s\" from %s to %s.".formatted(summary, start, end));
            }
            if (!response.authorized()) {
                return ToolResult.failed("Calendar rejected the credentials (%d)".formatted(
                        response.status()));
            }
            return ToolResult.failed("Calendar answered %d".formatted(response.status()));
        } catch (IllegalArgumentException exception) {
            return ToolResult.failed(describe(exception));
        } catch (RuntimeException exception) {
            return ToolResult.unknown("Calendar PUT outcome is unknown: " + describe(exception));
        }
    }

    private static String describe(RuntimeException exception) {
        var detail = exception.getMessage();
        return detail == null || detail.isBlank() ? exception.getClass().getSimpleName() : detail;
    }

    private static Instant instantOf(String value) {
        try {
            return Instant.parse(value);
        } catch (RuntimeException ignored) {
            // Fall through to the offset and local forms below.
        }
        try {
            return OffsetDateTime.parse(value).toInstant();
        } catch (RuntimeException ignored) {
            // Fall through to the local form below.
        }
        return LocalDateTime.parse(value).toInstant(ZoneOffset.UTC);
    }

    private static String renderEvent(
            String uid,
            String summary,
            Instant start,
            Instant end,
            String description,
            String location
    ) {
        var builder = new StringBuilder();
        builder.append("BEGIN:VCALENDAR\r\n");
        builder.append("VERSION:2.0\r\n");
        builder.append("PRODID:-//MicroFlow//Agent Runtime//EN\r\n");
        builder.append("BEGIN:VEVENT\r\n");
        builder.append("UID:").append(uid).append("\r\n");
        builder.append("DTSTAMP:").append(ICS_UTC.format(Instant.now())).append("\r\n");
        builder.append("DTSTART:").append(ICS_UTC.format(start)).append("\r\n");
        builder.append("DTEND:").append(ICS_UTC.format(end)).append("\r\n");
        builder.append("SUMMARY:").append(escape(summary)).append("\r\n");
        if (description != null && !description.isBlank()) {
            builder.append("DESCRIPTION:").append(escape(description)).append("\r\n");
        }
        if (location != null && !location.isBlank()) {
            builder.append("LOCATION:").append(escape(location)).append("\r\n");
        }
        builder.append("END:VEVENT\r\n");
        builder.append("END:VCALENDAR\r\n");
        return builder.toString();
    }

    /** RFC 5545 text escaping for the four characters that break a property. */
    private static String escape(String value) {
        return value
                .replace("\\", "\\\\")
                .replace(";", "\\;")
                .replace(",", "\\,")
                .replace("\n", "\\n");
    }
}
