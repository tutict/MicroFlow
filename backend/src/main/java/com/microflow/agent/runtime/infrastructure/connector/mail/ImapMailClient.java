package com.microflow.agent.runtime.infrastructure.connector.mail;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Minimal IMAP reader: LOGIN, SELECT, SEARCH, FETCH headers.
 *
 * <p>Scope is deliberate. MicroFlow needs "what is in this mailbox that matches
 * this query", not a mail client, so there is no IDLE, no attachment handling
 * and no synchronisation. Only headers are fetched, which keeps both the
 * traffic and the amount of personal data passing through the runtime small.
 */
public class ImapMailClient {

    private static final Pattern LITERAL_SUFFIX = Pattern.compile("\\{(\\d+)}$");
    private static final Pattern SEARCH_RESULT = Pattern.compile("\\* SEARCH(.*)");
    private static final Pattern ENCODED_WORD =
            Pattern.compile("=\\?([^?]+)\\?([BbQq])\\?([^?]*)\\?=");

    private static final String HEADER_FIELDS = "(BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])";

    public List<MailHeader> search(
            String host,
            int port,
            boolean implicitTls,
            boolean startTls,
            String username,
            String password,
            String mailbox,
            String criteria,
            int limit
    ) {
        var tagCounter = new int[] {0};
        try (var connection = MailConnection.open(host, port, implicitTls)) {
            var greeting = connection.readLine();
            if (greeting == null || !greeting.toUpperCase(Locale.ROOT).startsWith("* OK")
                    && !greeting.toUpperCase(Locale.ROOT).startsWith("* PREAUTH")) {
                throw new ImapException("Unexpected IMAP greeting: " + greeting);
            }
            if (startTls && !implicitTls) {
                expectOk(connection, command(connection, tagCounter, "STARTTLS"), "STARTTLS");
                connection.startTls();
            }
            expectOk(connection, command(connection, tagCounter,
                    "LOGIN " + quote(username) + " " + quote(password)), "LOGIN");
            expectOk(connection, command(connection, tagCounter,
                    "SELECT " + quote(mailbox)), "SELECT");

            var ids = searchIds(connection, tagCounter, criteria);
            if (ids.isEmpty()) {
                logout(connection, tagCounter);
                return List.of();
            }
            var selected = ids.subList(Math.max(0, ids.size() - Math.max(1, limit)), ids.size());
            var headers = fetchHeaders(connection, tagCounter, selected);
            logout(connection, tagCounter);
            return headers;
        } catch (IOException exception) {
            throw new ImapException("IMAP connection failed: " + exception.getMessage(), exception);
        }
    }

    private List<String> searchIds(MailConnection connection, int[] tag, String criteria)
            throws IOException {
        var tagId = nextTag(connection, tag, "SEARCH " + sanitizeCriteria(criteria));
        var ids = new ArrayList<String>();
        while (true) {
            var line = connection.readLine();
            if (line == null) {
                throw new ImapException("IMAP server closed the connection during SEARCH");
            }
            if (line.startsWith(tagId + " ")) {
                requireOk(line, "SEARCH");
                return ids;
            }
            var matcher = SEARCH_RESULT.matcher(line);
            if (matcher.find()) {
                for (var token : matcher.group(1).trim().split("\\s+")) {
                    if (!token.isBlank()) {
                        ids.add(token);
                    }
                }
            }
        }
    }

    private List<MailHeader> fetchHeaders(
            MailConnection connection,
            int[] tag,
            List<String> ids
    ) throws IOException {
        var tagId = nextTag(connection, tag, "FETCH " + String.join(",", ids) + " " + HEADER_FIELDS);
        var headers = new ArrayList<MailHeader>();
        while (true) {
            var line = connection.readLine();
            if (line == null) {
                return headers;
            }
            if (line.startsWith(tagId + " ")) {
                requireOk(line, "FETCH");
                return headers;
            }
            var literal = LITERAL_SUFFIX.matcher(line);
            if (literal.find()) {
                var length = Integer.parseInt(literal.group(1));
                headers.add(parseHeader(connection.readBytes(length)));
            }
        }
    }

    private MailHeader parseHeader(String raw) {
        String from = null;
        String subject = null;
        String date = null;
        for (var line : raw.split("\r?\n")) {
            var colon = line.indexOf(':');
            if (colon <= 0) {
                continue;
            }
            var name = line.substring(0, colon).trim().toLowerCase(Locale.ROOT);
            var value = line.substring(colon + 1).trim();
            switch (name) {
                case "from" -> from = decodeEncodedWords(value);
                case "subject" -> subject = decodeEncodedWords(value);
                case "date" -> date = value;
                default -> {
                    // Only the three fields above are exported; everything else is dropped.
                }
            }
        }
        return new MailHeader(from, subject, date);
    }

    /** Decodes {@code =?UTF-8?B?...?=} so a Chinese subject is readable. */
    private static String decodeEncodedWords(String value) {
        var matcher = ENCODED_WORD.matcher(value);
        var result = new StringBuilder();
        while (matcher.find()) {
            var charset = matcher.group(1).split("\\*")[0];
            var encoding = matcher.group(2).toUpperCase(Locale.ROOT);
            var payload = matcher.group(3);
            String decoded;
            try {
                var bytes = "B".equals(encoding)
                        ? Base64.getDecoder().decode(payload)
                        : decodeQuotedPrintable(payload);
                decoded = new String(bytes, charsetOf(charset));
            } catch (RuntimeException exception) {
                decoded = matcher.group();
            }
            matcher.appendReplacement(result, java.util.regex.Matcher.quoteReplacement(decoded));
        }
        matcher.appendTail(result);
        return result.toString();
    }

    private static java.nio.charset.Charset charsetOf(String name) {
        try {
            return java.nio.charset.Charset.forName(name);
        } catch (RuntimeException exception) {
            return StandardCharsets.UTF_8;
        }
    }

    private static byte[] decodeQuotedPrintable(String payload) {
        var out = new java.io.ByteArrayOutputStream();
        for (var index = 0; index < payload.length(); index++) {
            var current = payload.charAt(index);
            if (current == '=' && index + 2 < payload.length()) {
                try {
                    out.write(Integer.parseInt(payload.substring(index + 1, index + 3), 16));
                    index += 2;
                    continue;
                } catch (NumberFormatException exception) {
                    // Fall through and keep the literal '='.
                }
            }
            out.write(current);
        }
        return out.toByteArray();
    }

    private void logout(MailConnection connection, int[] tag) throws IOException {
        try {
            connection.write("M" + (++tag[0]) + " LOGOUT");
        } catch (IOException ignored) {
            // A failed logout does not change the result of the search.
        }
    }

    private String command(MailConnection connection, int[] tag, String body) throws IOException {
        return nextTag(connection, tag, body);
    }

    private String nextTag(MailConnection connection, int[] tag, String body) throws IOException {
        var tagId = "M" + (++tag[0]);
        connection.write(tagId + " " + body);
        return tagId;
    }

    private void expectOk(MailConnection connection, String tagId, String stage) throws IOException {
        while (true) {
            var line = connection.readLine();
            if (line == null) {
                throw new ImapException("IMAP server closed the connection during " + stage);
            }
            if (line.startsWith(tagId + " ")) {
                requireOk(line, stage);
                return;
            }
        }
    }

    private static void requireOk(String line, String stage) {
        var upper = line.toUpperCase(Locale.ROOT);
        if (!upper.contains(" OK")) {
            throw new ImapException("IMAP " + stage + " failed: " + line.trim());
        }
    }

    /**
     * Rejects anything that could inject a second IMAP command. The criteria
     * string comes from a model, so this is a trust boundary, not a nicety.
     */
    private static String sanitizeCriteria(String criteria) {
        var value = criteria == null || criteria.isBlank() ? "ALL" : criteria.trim();
        if (value.indexOf('\r') >= 0 || value.indexOf('\n') >= 0) {
            throw new ImapException("IMAP search criteria must not contain line breaks");
        }
        return value;
    }

    private static String quote(String value) {
        var safe = value == null ? "" : value;
        return "\"" + safe.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }

    /** One matching message: headers only, no body. */
    public record MailHeader(String from, String subject, String date) {

        public String summary() {
            return "%s | %s".formatted(
                    subject == null ? "(no subject)" : subject,
                    from == null ? "(unknown sender)" : from);
        }
    }

    /** Protocol-level failure. Nothing was mutated, so retrying is safe. */
    public static class ImapException extends RuntimeException {

        public ImapException(String message) {
            super(message);
        }

        public ImapException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
