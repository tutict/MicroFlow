package com.microflow.agent.runtime.infrastructure.connector;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import org.springframework.stereotype.Component;

/**
 * Thin HTTP layer shared by the CalDAV/WebDAV probe and tools.
 *
 * <p>Exists so authentication, timeouts and non-standard methods
 * ({@code PROPFIND}) live in one place; {@code java.net.http.HttpClient} needs
 * the explicit {@code method(...)} form for WebDAV verbs, which is easy to get
 * subtly wrong in five separate call sites.
 */
@Component
public class ConnectorHttpClient {

    private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(10);
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(30);

    private final HttpClient client;

    public ConnectorHttpClient() {
        this(HttpClient.newBuilder()
                .connectTimeout(CONNECT_TIMEOUT)
                .followRedirects(HttpClient.Redirect.NORMAL)
                .build());
    }

    ConnectorHttpClient(HttpClient client) {
        this.client = client;
    }

    public Response propfind(String url, String username, String password, int depth) {
        return send("PROPFIND", url, username, password, DEPTH_BODY, "application/xml; charset=utf-8",
                depth);
    }

    public Response put(String url, String username, String password, String contentType, String body) {
        return send("PUT", url, username, password, body, contentType, -1);
    }

    public Response get(String url, String username, String password) {
        return send("GET", url, username, password, null, null, -1);
    }

    public Response send(
            String method,
            String url,
            String username,
            String password,
            String body,
            String contentType,
            int depth
    ) {
        if (url == null || url.isBlank()) {
            throw new IllegalArgumentException("Connector URL is required");
        }
        var builder = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .timeout(REQUEST_TIMEOUT);
        if (username != null) {
            var token = Base64.getEncoder().encodeToString(
                    (username + ":" + (password == null ? "" : password))
                            .getBytes(StandardCharsets.UTF_8));
            builder.header("Authorization", "Basic " + token);
        }
        if (depth >= 0) {
            builder.header("Depth", Integer.toString(depth));
        }
        if (contentType != null) {
            builder.header("Content-Type", contentType);
        }
        var publisher = body == null
                ? HttpRequest.BodyPublishers.noBody()
                : HttpRequest.BodyPublishers.ofString(body, StandardCharsets.UTF_8);
        builder.method(method, publisher);
        try {
            var response = client.send(builder.build(), HttpResponse.BodyHandlers.ofString());
            return new Response(response.statusCode(), response.body());
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Connector request interrupted", exception);
        } catch (Exception exception) {
            throw new IllegalStateException(describe(exception), exception);
        }
    }

    private static String describe(Exception exception) {
        var message = exception.getMessage();
        return message == null || message.isBlank()
                ? exception.getClass().getSimpleName()
                : message;
    }

    /** Minimal multistatus body: we only need a 207, not the property list. */
    private static final String DEPTH_BODY = """
            <?xml version="1.0" encoding="utf-8"?>
            <d:propfind xmlns:d="DAV:">
              <d:prop>
                <d:resourcetype/>
                <d:displayname/>
                <d:getcontentlength/>
                <d:getlastmodified/>
              </d:prop>
            </d:propfind>
            """;

    public record Response(int status, String body) {

        public boolean successful() {
            return status >= 200 && status < 300;
        }

        /** WebDAV answers multi-status 207 for a successful PROPFIND. */
        public boolean multiStatus() {
            return status == 207;
        }

        public boolean authorized() {
            return status != 401 && status != 403;
        }
    }
}
