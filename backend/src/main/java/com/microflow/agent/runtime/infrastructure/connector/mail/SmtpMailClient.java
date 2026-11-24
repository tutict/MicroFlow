package com.microflow.agent.runtime.infrastructure.connector.mail;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Base64;
import java.util.List;
import java.util.Locale;

/**
 * Minimal ESMTP sender.
 *
 * <p>Written against the wire protocol rather than a mail library so the
 * approval story stays honest: the moment {@code DATA} is accepted the message
 * may already be delivered, and this class raises
 * {@link UncertainDeliveryException} instead of a plain failure so the runtime
 * records an {@code UNKNOWN} outcome and refuses to retry automatically.
 */
public class SmtpMailClient {

    private static final DateTimeFormatter RFC_5322_DATE =
            DateTimeFormatter.ofPattern("EEE, d MMM yyyy HH:mm:ss Z", Locale.US);

    private final Clock clock;

    public SmtpMailClient(Clock clock) {
        this.clock = clock;
    }

    public SendResult send(
            String host,
            int port,
            boolean startTls,
            String username,
            String password,
            String from,
            List<String> recipients,
            String subject,
            String body
    ) {
        var implicitTls = port == 465;
        var message = renderMessage(from, recipients, subject, body);
        var bodyStarted = false;
        try (var connection = MailConnection.open(host, port, implicitTls)) {
            expect(connection.readLine(), 220, "SMTP greeting");
            connection.write("EHLO microflow");
            expect(connection.readReply(), 250, "EHLO");

            if (startTls && !implicitTls) {
                connection.write("STARTTLS");
                expect(connection.readReply(), 220, "STARTTLS");
                connection.startTls();
                connection.write("EHLO microflow");
                expect(connection.readReply(), 250, "EHLO after STARTTLS");
            }

            if (username != null && !username.isBlank()) {
                authenticate(connection, username, password);
            }

            connection.write("MAIL FROM:<" + from + ">");
            expect(connection.readReply(), 250, "MAIL FROM");
            for (var recipient : recipients) {
                connection.write("RCPT TO:<" + recipient + ">");
                var reply = connection.readReply();
                if (replyCode(reply) != 250 && replyCode(reply) != 251) {
                    throw new SmtpException("RCPT TO " + recipient + " was rejected: " + reply);
                }
            }
            connection.write("DATA");
            expect(connection.readReply(), 354, "DATA");
            bodyStarted = true;
            connection.writeRaw(message);
            var completion = connection.readReply();
            expect(completion, 250, "message body");
            connection.write("QUIT");
            return new SendResult(recipients.size(), completion.trim());
        } catch (IOException exception) {
            if (bodyStarted) {
                throw new UncertainDeliveryException(
                        "SMTP connection failed after the message body was sent: " + exception.getMessage(),
                        exception);
            }
            throw new SmtpException("SMTP connection failed: " + exception.getMessage(), exception);
        } catch (UncertainDeliveryException exception) {
            throw exception;
        } catch (RuntimeException exception) {
            if (bodyStarted) {
                throw new UncertainDeliveryException(
                        "SMTP session failed after the message body was sent: " + exception.getMessage(),
                        exception);
            }
            throw exception;
        }
    }

    private void authenticate(MailConnection connection, String username, String password)
            throws IOException {
        var token = Base64.getEncoder().encodeToString(
                ("\0" + username + "\0" + (password == null ? "" : password))
                        .getBytes(StandardCharsets.UTF_8));
        connection.write("AUTH PLAIN " + token);
        var reply = connection.readReply();
        if (replyCode(reply) == 235) {
            return;
        }
        if (replyCode(reply) != 504 && replyCode(reply) != 500) {
            throw new SmtpException("SMTP authentication was rejected: " + reply);
        }
        // Server does not speak AUTH PLAIN; fall back to AUTH LOGIN.
        connection.write("AUTH LOGIN");
        expect(connection.readReply(), 334, "AUTH LOGIN");
        connection.write(Base64.getEncoder().encodeToString(username.getBytes(StandardCharsets.UTF_8)));
        expect(connection.readReply(), 334, "AUTH LOGIN username");
        connection.write(Base64.getEncoder().encodeToString(
                (password == null ? "" : password).getBytes(StandardCharsets.UTF_8)));
        expect(connection.readReply(), 235, "AUTH LOGIN password");
    }

    private String renderMessage(
            String from,
            List<String> recipients,
            String subject,
            String body
    ) {
        var builder = new StringBuilder();
        builder.append("From: ").append(from).append("\r\n");
        builder.append("To: ").append(String.join(", ", recipients)).append("\r\n");
        builder.append("Subject: ").append(encodeHeader(subject)).append("\r\n");
        builder.append("Date: ").append(RFC_5322_DATE.format(ZonedDateTime.now(clock))).append("\r\n");
        builder.append("MIME-Version: 1.0\r\n");
        builder.append("Content-Type: text/plain; charset=UTF-8\r\n");
        builder.append("Content-Transfer-Encoding: base64\r\n");
        builder.append("\r\n");
        var encoded = Base64.getMimeEncoder(76, "\r\n".getBytes(StandardCharsets.US_ASCII))
                .encodeToString((body == null ? "" : body).getBytes(StandardCharsets.UTF_8));
        builder.append(encoded).append("\r\n");
        builder.append(".\r\n");
        return builder.toString();
    }

    /**
     * RFC 2047 encoding for non-ASCII headers. Plain ASCII is sent as-is so the
     * common case stays readable in a raw transcript.
     */
    private static String encodeHeader(String value) {
        var text = value == null ? "" : value.replace("\r", " ").replace("\n", " ");
        var ascii = text.chars().allMatch(code -> code < 128);
        if (ascii) {
            return text;
        }
        return "=?UTF-8?B?"
                + Base64.getEncoder().encodeToString(text.getBytes(StandardCharsets.UTF_8))
                + "?=";
    }

    private static void expect(String reply, int expectedCode, String stage) {
        if (reply == null) {
            throw new SmtpException("SMTP server closed the connection during " + stage);
        }
        var code = replyCode(reply);
        if (code != expectedCode) {
            throw new SmtpException("SMTP " + stage + " failed: " + reply.trim());
        }
    }

    private static int replyCode(String reply) {
        if (reply == null || reply.length() < 3) {
            return -1;
        }
        try {
            return Integer.parseInt(reply.substring(0, 3));
        } catch (NumberFormatException exception) {
            return -1;
        }
    }

    public record SendResult(int recipientCount, String serverReply) {
    }

    /** The server answered, but not what the protocol requires. */
    public static class SmtpException extends RuntimeException {

        public SmtpException(String message) {
            super(message);
        }

        public SmtpException(String message, Throwable cause) {
            super(message, cause);
        }
    }

    /**
     * Delivery may or may not have happened. Callers must not retry without a
     * human checking the mailbox first.
     */
    public static class UncertainDeliveryException extends RuntimeException {

        public UncertainDeliveryException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
