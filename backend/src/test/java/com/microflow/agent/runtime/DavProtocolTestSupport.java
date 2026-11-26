package com.microflow.agent.runtime;

import static org.assertj.core.api.Assertions.assertThat;

import tools.jackson.databind.ObjectMapper;
import com.microflow.testing.MicroFlowApiTestSupport;
import com.microflow.testing.QuarkusRestTemplate;
import jakarta.inject.Inject;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;
import org.springframework.http.HttpStatus;

/** Test-only API setup and a real loopback PUT peer; no HTTP client is mocked. */
abstract class DavProtocolTestSupport extends MicroFlowApiTestSupport {

    protected final QuarkusRestTemplate rest = new QuarkusRestTemplate();
    @Inject protected ObjectMapper mapper;

    protected record Run(Session owner, String id, String approvalId) { }

    protected Run waitingRun(String kind, DavServer peer) {
        var owner = register(rest, mapper, kind.toLowerCase() + System.nanoTime() + "@example.com", "DAV Owner");
        var workspaceId = createWorkspace(rest, mapper, owner, "Local " + kind);
        var connector = post(rest, "/api/v1/workspaces/" + workspaceId + "/connectors", owner, Map.of(
                "kind", kind, "name", "Loopback DAV", "sharingScope", "PRIVATE",
                "config", Map.of("baseUrl", peer.baseUrl()),
                "secrets", Map.of("username", "fixture", "password", "test-only")));
        assertThat(connector.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        var taskId = createTaskId(rest, mapper, owner, workspaceId, Map.of("title", "DAV protocol write"));
        var response = post(rest, "/api/v1/workspaces/" + workspaceId + "/tasks/" + taskId + "/agent-runs",
                owner, Map.of("goal", "Perform the approved DAV write"));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        var runId = (String) readMap(mapper, response.getBody()).get("id");
        awaitStatus(owner, runId, "WAITING_APPROVAL");
        var approvals = readList(mapper, get(rest, "/api/v1/agent-runs/" + runId + "/approvals?status=PENDING", owner).getBody());
        assertThat(approvals).hasSize(1);
        assertThat(peer.requests).as("approval must hold before any PUT reaches the peer").isEmpty();
        return new Run(owner, runId, (String) approvals.getFirst().get("id"));
    }

    protected void decide(Run run, String decision) {
        var response = post(rest, "/api/v1/agent-runs/" + run.id + "/approvals/" + run.approvalId + "/decision",
                run.owner, Map.of("decision", decision));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    protected void assertUnknownAndRefusedRetry(Run run, DavServer peer) {
        var failed = awaitStatus(run.owner, run.id, "FAILED");
        assertThat(failed.get("errorMessage")).asString().containsIgnoringCase("unknown");
        var invocations = readList(mapper, get(rest, "/api/v1/agent-runs/" + run.id + "/tool-invocations", run.owner).getBody());
        assertThat(invocations).hasSize(1);
        assertThat(invocations.getFirst().get("status")).isEqualTo("UNKNOWN");
        assertThat(peer.requests).as("one complete PUT arrived despite the missing response").hasSize(1);
        var received = List.copyOf(peer.requests);
        var retry = post(rest, "/api/v1/agent-runs/" + run.id + "/retry", run.owner, Map.of());
        assertThat(retry.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(peer.requests).as("refused retry preserves target, body and operation count").containsExactlyElementsOf(received);
    }

    protected Map<String, Object> awaitStatus(Session owner, String runId, String expected) {
        var deadline = System.nanoTime() + Duration.ofSeconds(20).toNanos();
        Map<String, Object> last = Map.of();
        while (System.nanoTime() < deadline) {
            last = readMap(mapper, get(rest, "/api/v1/agent-runs/" + runId, owner).getBody());
            if (expected.equals(last.get("status"))) return last;
            if (List.of("FAILED", "SUCCEEDED", "CANCELLED").contains(last.get("status"))) {
                assertThat(last.get("status")).as("terminal run status, error: %s", last.get("errorMessage")).isEqualTo(expected);
            }
            try {
                Thread.sleep(50);
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                throw new AssertionError("Interrupted waiting for DAV run", exception);
            }
        }
        throw new AssertionError("Timed out waiting for " + expected + ": " + last);
    }

    static final class DavServer implements AutoCloseable {
        final List<Request> requests = new CopyOnWriteArrayList<>();
        private final ServerSocket listener = new ServerSocket(0, 10, InetAddress.getLoopbackAddress());
        private final Thread thread;
        private final boolean dropAfterBody;
        private final int status;
        private volatile Throwable failure;

        DavServer(boolean dropAfterBody, int status) throws IOException {
            this.dropAfterBody = dropAfterBody;
            this.status = status;
            thread = new Thread(this::serve, "dav-protocol-peer");
            thread.setDaemon(true);
            thread.start();
        }

        String baseUrl() { return "http://localhost:" + listener.getLocalPort() + "/calendar"; }

        private void serve() {
            while (!listener.isClosed()) {
                try (var socket = listener.accept()) {
                    socket.setSoTimeout(5000);
                    var input = socket.getInputStream();
                    var first = readLine(input);
                    if (first == null) continue;
                    int length = 0;
                    String type = null;
                    String line;
                    while ((line = readLine(input)) != null && !line.isEmpty()) {
                        var colon = line.indexOf(':');
                        if (colon < 0) continue;
                        var name = line.substring(0, colon);
                        var value = line.substring(colon + 1).trim();
                        if (name.equalsIgnoreCase("Content-Length")) length = Integer.parseInt(value);
                        if (name.equalsIgnoreCase("Content-Type")) type = value;
                    }
                    var body = input.readNBytes(length);
                    if (body.length != length) throw new IOException("Incomplete PUT fixture body");
                    var parts = first.split(" ");
                    requests.add(new Request(parts[0], parts[1], type, new String(body, StandardCharsets.UTF_8)));
                    if (!dropAfterBody) {
                        socket.getOutputStream().write(("HTTP/1.1 " + status + " Fixture\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
                                .getBytes(StandardCharsets.US_ASCII));
                        socket.getOutputStream().flush();
                    }
                } catch (Exception exception) {
                    if (!listener.isClosed()) failure = exception;
                }
            }
        }

        private static String readLine(InputStream input) throws IOException {
            var buffer = new ByteArrayOutputStream();
            int value;
            while ((value = input.read()) != -1) {
                if (value == '\n') return buffer.toString(StandardCharsets.US_ASCII).replaceFirst("\\r$", "");
                buffer.write(value);
                if (buffer.size() > 65536) throw new IOException("Oversized fixture header");
            }
            return buffer.size() == 0 ? null : buffer.toString(StandardCharsets.US_ASCII);
        }

        @Override public void close() throws Exception {
            listener.close();
            thread.join(6000);
            assertThat(thread.isAlive()).as("DAV peer thread stopped").isFalse();
            assertThat(failure).as("DAV peer must not conceal a malformed protocol exchange").isNull();
        }
    }

    record Request(String method, String target, String contentType, String body) { }
}
