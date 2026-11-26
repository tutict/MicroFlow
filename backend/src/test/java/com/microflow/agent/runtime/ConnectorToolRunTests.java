package com.microflow.agent.runtime;

import static org.assertj.core.api.Assertions.assertThat;

import tools.jackson.databind.ObjectMapper;
import com.microflow.testing.MicroFlowApiTestSupport;
import com.microflow.testing.QuarkusRestTemplate;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.QuarkusTestProfile;
import io.quarkus.test.junit.TestProfile;
import jakarta.inject.Inject;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/**
 * The connector write path, end to end over HTTP.
 *
 * <p>The runtime's generic approval tests use the internal task tools, where a
 * failed write leaves nothing behind. This class covers the case the harness was
 * actually built for: an external action whose outcome can be unknown. A local
 * SMTP server accepts the message body and then hangs up, which is exactly the
 * scenario where a naive retry would deliver the same mail twice.
 */
@QuarkusTest
@TestProfile(ConnectorToolRunTests.Profile.class)
class ConnectorToolRunTests extends MicroFlowApiTestSupport {

    private static final Path databasePath = createDatabasePath();

    private static final String MOCK_PLAN = """
            {"turns":[
              {"text":"Sending the weekly update.","toolCalls":[
                {"callId":"call_mail","toolKey":"mail.send","input":{
                  "to":["ops@example.com"],
                  "subject":"Weekly update",
                  "body":"All clear this week."
                }}
              ]},
              {"text":"The update is out."}
            ]}
            """;

    public static class Profile implements QuarkusTestProfile {
        @Override
        public Map<String, String> getConfigOverrides() {
            return Map.of(
                    "microflow.database.path", databasePath.toAbsolutePath().toString(),
                    "microflow.agent.mock-delay", "PT0.02S",
                    "microflow.agent.mock-plan", MOCK_PLAN,
                    "microflow.agent.openclaw-state-dir",
                    databasePath.resolveSibling("missing-qclaw-state").toString(),
                    "microflow.seed.demo-enabled", "false",
                    "microflow.jwt.secret", "connector-tool-test-jwt-secret-with-entropy",
                    "microflow.crypto.secret", "ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA="
            );
        }
    }

    private static Path createDatabasePath() {
        try {
            return Files.createTempDirectory("microflow-connector-tool-tests").resolve("connector.db");
        } catch (IOException exception) {
            throw new IllegalStateException("Unable to create a connector test database path", exception);
        }
    }

    @AfterAll
    static void cleanDatabase() {
        try {
            Files.deleteIfExists(databasePath);
        } catch (IOException ignored) {
            // Windows may still hold the SQLite file handle briefly after shutdown.
        }
    }

    private final QuarkusRestTemplate restTemplate = new QuarkusRestTemplate();

    @Inject
    private ObjectMapper objectMapper;

    @Test
    void approvedMailThatEndsUnknownIsSentOnceAndNeverRetried() throws IOException {
        try (var smtp = new FakeSmtpServer(true)) {
            var owner = register(restTemplate, objectMapper, uniqueEmail("mail"), "Mailer");
            var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Connector Mail");
            createSmtpConnector(owner, workspaceId, smtp.port());
            var taskId = createTaskId(restTemplate, objectMapper, owner, workspaceId, Map.of(
                    "title", "Send the weekly update"));

            var runId = startRun(owner, workspaceId, taskId);
            awaitStatus(owner, runId, "WAITING_APPROVAL");

            // The gate holds: no socket was opened before the human approved.
            assertThat(smtp.connections())
                    .as("an unapproved external write must not reach the network")
                    .isZero();

            var approvals = readList(objectMapper, get(
                    restTemplate,
                    "/api/v1/agent-runs/" + runId + "/approvals?status=PENDING",
                    owner).getBody());
            assertThat(approvals).hasSize(1);
            var approval = approvals.getFirst();
            assertThat(approval.get("toolKey")).isEqualTo("mail.send");
            assertThat(approval.get("riskLevel")).isEqualTo("EXTERNAL_WRITE");
            assertThat(approval.get("targetResource")).isEqualTo("task:" + taskId);
            assertThat(approval.get("impactSummary")).asString()
                    .contains("ops@example.com")
                    .contains("Weekly update");

            var decision = post(
                    restTemplate,
                    "/api/v1/agent-runs/" + runId + "/approvals/" + approval.get("id") + "/decision",
                    owner,
                    Map.of("decision", "APPROVE"));
            assertThat(decision.getStatusCode()).isEqualTo(HttpStatus.OK);

            var finished = awaitStatus(owner, runId, "FAILED");
            assertThat(finished.get("errorMessage")).asString().contains("unknown");
            assertThat(smtp.deliveries())
                    .as("the message body was accepted exactly once")
                    .isEqualTo(1);
            assertThat(smtp.connections()).isEqualTo(1);

            var invocations = readList(objectMapper, get(
                    restTemplate, "/api/v1/agent-runs/" + runId + "/tool-invocations", owner).getBody());
            assertThat(invocations).hasSize(1);
            assertThat(invocations.getFirst().get("status")).isEqualTo("UNKNOWN");

            var retry = post(
                    restTemplate, "/api/v1/agent-runs/" + runId + "/retry", owner, Map.of());
            assertThat(retry.getStatusCode())
                    .as("a run with an unknown external outcome must not be replayable")
                    .isEqualTo(HttpStatus.CONFLICT);
            assertThat(smtp.deliveries())
                    .as("refusing the retry must not send the mail a second time")
                    .isEqualTo(1);
            assertThat(smtp.connections()).isEqualTo(1);
        }
    }

    @Test
    void rejectedMailApprovalNeverOpensTheConnection() throws IOException {
        try (var smtp = new FakeSmtpServer(false)) {
            var owner = register(restTemplate, objectMapper, uniqueEmail("mailreject"), "Rejecter");
            var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Connector Mail Reject");
            createSmtpConnector(owner, workspaceId, smtp.port());
            var taskId = createTaskId(restTemplate, objectMapper, owner, workspaceId, Map.of(
                    "title", "Send the weekly update"));

            var runId = startRun(owner, workspaceId, taskId);
            awaitStatus(owner, runId, "WAITING_APPROVAL");
            var approvals = readList(objectMapper, get(
                    restTemplate,
                    "/api/v1/agent-runs/" + runId + "/approvals?status=PENDING",
                    owner).getBody());
            var approvalId = (String) approvals.getFirst().get("id");

            var decision = post(
                    restTemplate,
                    "/api/v1/agent-runs/" + runId + "/approvals/" + approvalId + "/decision",
                    owner,
                    Map.of("decision", "REJECT", "note", "Wrong audience"));

            assertThat(decision.getStatusCode()).isEqualTo(HttpStatus.OK);
            assertThat(readMap(objectMapper, decision.getBody()).get("status")).isEqualTo("REJECTED");

            // A rejected action does not fail the run: the model is told "no" and
            // finishes the turn. What matters is that the network was untouched.
            awaitStatus(owner, runId, "SUCCEEDED");
            assertThat(smtp.connections()).isZero();
            assertThat(smtp.deliveries()).isZero();

            var invocations = readList(objectMapper, get(
                    restTemplate, "/api/v1/agent-runs/" + runId + "/tool-invocations", owner).getBody());
            assertThat(invocations).anySatisfy(invocation ->
                    assertThat(invocation.get("status")).isEqualTo("REJECTED"));

            var events = readList(objectMapper, get(
                    restTemplate, "/api/v1/agent-runs/" + runId + "/events", owner).getBody());
            var types = events.stream().map(event -> (String) event.get("type")).toList();
            assertThat(types).contains("APPROVAL_REJECTED").doesNotContain("TOOL_STARTED");
        }
    }

    // ------------------------------------------------------------------ helpers

    private void createSmtpConnector(Session owner, String workspaceId, int port) {
        var response = post(
                restTemplate,
                "/api/v1/workspaces/" + workspaceId + "/connectors",
                owner,
                Map.of(
                        "kind", "SMTP",
                        "name", "Fake SMTP",
                        "config", Map.of(
                                "host", "127.0.0.1",
                                "port", port,
                                "tls", false,
                                "fromAddress", "microflow@example.com"),
                        "secrets", Map.of(
                                "username", "microflow",
                                "password", "app-password"),
                        "sharingScope", "PRIVATE"));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }

    private String uniqueEmail(String prefix) {
        return prefix + "-" + System.nanoTime() + "@example.com";
    }

    private String startRun(Session session, String workspaceId, String taskId) {
        var response = post(
                restTemplate,
                "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/agent-runs",
                session,
                Map.of("goal", "Send the weekly update"));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        var body = readMap(objectMapper, response.getBody());
        assertThat(body.get("id")).isNotNull();
        return (String) body.get("id");
    }

    private Map<String, Object> awaitStatus(Session session, String runId, String expected) {
        var deadline = System.nanoTime() + Duration.ofSeconds(20).toNanos();
        Map<String, Object> last = Map.of();
        while (System.nanoTime() < deadline) {
            var response = get(restTemplate, "/api/v1/agent-runs/" + runId, session);
            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
            last = readMap(objectMapper, response.getBody());
            if (expected.equals(last.get("status"))) {
                return last;
            }
            if ("SUCCEEDED".equals(last.get("status")) || "FAILED".equals(last.get("status"))) {
                assertThat(last.get("status"))
                        .as("run %s ended as %s (%s)", runId, last.get("status"), last.get("errorMessage"))
                        .isEqualTo(expected);
            }
            try {
                Thread.sleep(100);
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                break;
            }
        }
        throw new AssertionError("Timed out waiting for run %s to reach %s, last status %s"
                .formatted(runId, expected, last.get("status")));
    }

    /**
     * A throwaway SMTP server that speaks just enough ESMTP for the client to
     * reach the body, then optionally drops the connection before acknowledging
     * it — the "did it land?" case the runtime must not retry.
     */
    private static final class FakeSmtpServer implements AutoCloseable {

        private final ServerSocket serverSocket;
        private final Thread thread;
        private final boolean dropAfterBody;
        private final AtomicInteger connections = new AtomicInteger();
        private final AtomicInteger deliveries = new AtomicInteger();

        FakeSmtpServer(boolean dropAfterBody) throws IOException {
            this.dropAfterBody = dropAfterBody;
            this.serverSocket = new ServerSocket(0, 1, InetAddress.getLoopbackAddress());
            this.thread = new Thread(this::serve, "fake-smtp");
            this.thread.setDaemon(true);
            this.thread.start();
        }

        int port() {
            return serverSocket.getLocalPort();
        }

        int connections() {
            return connections.get();
        }

        int deliveries() {
            return deliveries.get();
        }

        private void serve() {
            while (!serverSocket.isClosed()) {
                try (var socket = serverSocket.accept()) {
                    connections.incrementAndGet();
                    handle(socket);
                } catch (IOException exception) {
                    return;
                }
            }
        }

        private void handle(Socket socket) throws IOException {
            var reader = new BufferedReader(
                    new InputStreamReader(socket.getInputStream(), StandardCharsets.US_ASCII));
            var writer = new BufferedWriter(
                    new OutputStreamWriter(socket.getOutputStream(), StandardCharsets.US_ASCII));
            reply(writer, "220 fake.local ESMTP");
            var inBody = false;
            String line;
            while ((line = reader.readLine()) != null) {
                if (inBody) {
                    if (".".equals(line)) {
                        deliveries.incrementAndGet();
                        if (dropAfterBody) {
                            return;
                        }
                        reply(writer, "250 2.0.0 queued");
                        inBody = false;
                    }
                    continue;
                }
                var command = line.toUpperCase(Locale.ROOT);
                if (command.startsWith("EHLO")) {
                    reply(writer, "250-fake.local");
                    reply(writer, "250 AUTH PLAIN LOGIN");
                } else if (command.startsWith("AUTH PLAIN")) {
                    reply(writer, "235 2.7.0 authenticated");
                } else if (command.startsWith("MAIL FROM") || command.startsWith("RCPT TO")) {
                    reply(writer, "250 2.1.0 ok");
                } else if (command.equals("DATA")) {
                    reply(writer, "354 end with <CRLF>.<CRLF>");
                    inBody = true;
                } else if (command.equals("QUIT")) {
                    reply(writer, "221 2.0.0 bye");
                    return;
                } else {
                    reply(writer, "250 2.0.0 ok");
                }
            }
        }

        private static void reply(BufferedWriter writer, String line) throws IOException {
            writer.write(line + "\r\n");
            writer.flush();
        }

        @Override
        public void close() throws IOException {
            serverSocket.close();
            thread.interrupt();
        }
    }
}
