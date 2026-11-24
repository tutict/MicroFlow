package com.microflow.agent.runtime;

import static org.assertj.core.api.Assertions.assertThat;

import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.QuarkusTestProfile;
import io.quarkus.test.junit.TestProfile;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import org.junit.jupiter.api.Test;

@QuarkusTest
@TestProfile(WebdavProtocolRunTests.Profile.class)
class WebdavProtocolRunTests extends DavProtocolTestSupport {
    private static final Path DATABASE = database();
    private static Path database() {
        try { return Files.createTempDirectory("webdav-protocol-run").resolve("fixture.db"); }
        catch (Exception exception) { throw new IllegalStateException(exception); }
    }
    public static class Profile implements QuarkusTestProfile {
        @Override public Map<String, String> getConfigOverrides() {
            return Map.of("microflow.database.path", DATABASE.toString(),
                    "microflow.agent.mock-delay", "PT0.01S",
                    "microflow.agent.openclaw-state-dir", DATABASE.resolveSibling("missing-state").toString(),
                    "microflow.seed.demo-enabled", "false",
                    "microflow.jwt.secret", "webdav-protocol-test-jwt-secret-with-entropy",
                    "microflow.crypto.secret", "ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA=",
                    "microflow.agent.mock-plan", """
                        {"turns":[{"toolCalls":[{"callId":"webdav-wire","toolKey":"webdav.write","input":{
                          "path":"notes/review.txt","content":"Protocol fixture content"}}]},
                          {"text":"WebDAV operation reviewed."}]}
                        """);
        }
    }

    @Test void approvedTextFileReachesFixedTarget() throws Exception {
        try (var peer = new DavServer(false, 201)) {
            var run = waitingRun("WEBDAV", peer);
            decide(run, "APPROVE");
            awaitStatus(run.owner(), run.id(), "SUCCEEDED");
            assertThat(peer.requests).containsExactly(new Request("PUT", "/calendar/notes/review.txt",
                    "text/plain; charset=utf-8", "Protocol fixture content"));
        }
    }

    @Test void webdavBodyAcceptedWithoutReplyIsUnknownAndCannotRetry() throws Exception {
        try (var peer = new DavServer(true, 201)) {
            var run = waitingRun("WEBDAV", peer);
            decide(run, "APPROVE");
            assertUnknownAndRefusedRetry(run, peer);
            assertThat(peer.requests.getFirst().target()).isEqualTo("/calendar/notes/review.txt");
            assertThat(peer.requests.getFirst().body()).isEqualTo("Protocol fixture content");
        }
    }

    @Test void rejectedWebdavApprovalSendsNoPut() throws Exception {
        try (var peer = new DavServer(false, 201)) {
            var run = waitingRun("WEBDAV", peer);
            decide(run, "REJECT");
            awaitStatus(run.owner(), run.id(), "SUCCEEDED");
            assertThat(peer.requests).isEmpty();
        }
    }
}
