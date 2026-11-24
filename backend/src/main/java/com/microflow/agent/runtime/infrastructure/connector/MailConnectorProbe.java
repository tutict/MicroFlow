package com.microflow.agent.runtime.infrastructure.connector;

import com.microflow.agent.runtime.domain.connector.ConnectorProbe;
import com.microflow.agent.runtime.domain.model.AgentConnector;
import com.microflow.agent.runtime.domain.model.ConnectorKind;
import com.microflow.agent.runtime.domain.model.ConnectorSettings;
import com.microflow.agent.runtime.infrastructure.connector.mail.MailConnection;
import java.util.Locale;
import java.util.Map;
import org.springframework.stereotype.Component;

/**
 * Reachability check for IMAP and SMTP.
 *
 * <p>Completes the protocol greeting (and {@code EHLO} for SMTP) rather than
 * merely opening a TCP port, because "something is listening" is not the signal
 * a user needs. Credentials are still validated on the first real read or send:
 * an authentication round-trip on every settings visit would trip account
 * lockouts on providers that count failed logins.
 */
@Component
public class MailConnectorProbe implements ConnectorProbe {

    @Override
    public boolean supports(ConnectorKind kind) {
        return kind == ConnectorKind.IMAP || kind == ConnectorKind.SMTP;
    }

    @Override
    public ProbeOutcome test(AgentConnector connector, Map<String, String> credentials) {
        var config = connector.config();
        var host = ConnectorSettings.string(config, "host", null);
        if (host == null) {
            return ProbeOutcome.failed("host is not configured");
        }
        var defaultPort = connector.kind() == ConnectorKind.IMAP ? 993 : 587;
        var port = ConnectorSettings.integer(config, "port", defaultPort);
        var tls = ConnectorSettings.bool(config, "tls", true);
        var implicitTls = connector.kind() == ConnectorKind.IMAP ? tls : port == 465;
        try (var connection = MailConnection.open(host, port, implicitTls)) {
            var greeting = connection.readLine();
            if (greeting == null) {
                return ProbeOutcome.failed("Server closed the connection without a greeting");
            }
            if (connector.kind() == ConnectorKind.IMAP) {
                var upper = greeting.toUpperCase(Locale.ROOT);
                if (upper.startsWith("* OK") || upper.startsWith("* PREAUTH")) {
                    return ProbeOutcome.ok("IMAP greeting received on port " + port);
                }
                return ProbeOutcome.failed("Unexpected IMAP greeting: " + greeting.trim());
            }
            if (!greeting.startsWith("220")) {
                return ProbeOutcome.failed("Unexpected SMTP greeting: " + greeting.trim());
            }
            connection.write("EHLO microflow");
            var reply = connection.readReply();
            if (reply != null && reply.startsWith("250")) {
                return ProbeOutcome.ok("SMTP accepted EHLO on port " + port);
            }
            return ProbeOutcome.failed("Unexpected EHLO reply: " + (reply == null ? "none" : reply.trim()));
        } catch (Exception exception) {
            var detail = exception.getMessage();
            return ProbeOutcome.failed(
                    detail == null || detail.isBlank() ? exception.getClass().getSimpleName() : detail);
        }
    }
}
