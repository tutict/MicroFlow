package com.microflow.agent.runtime;

import static org.assertj.core.api.Assertions.assertThat;

import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.QuarkusTestProfile;
import io.quarkus.test.junit.TestProfile;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.Map;
import org.junit.jupiter.api.Test;

@QuarkusTest
@TestProfile(CalendarProtocolRunTests.Profile.class)
class CalendarProtocolRunTests extends DavProtocolTestSupport {
    private static final Path DATABASE = database();
    private static Path database() {
        try { return Files.createTempDirectory("calendar-protocol-run").resolve("fixture.db"); }
        catch (Exception exception) { throw new IllegalStateException(exception); }
    }

    public static class Profile implements QuarkusTestProfile {
        @Override public Map<String, String> getConfigOverrides() {
            return Map.of("microflow.database.path", DATABASE.toString(),
                    "microflow.agent.mock-delay", "PT0.01S",
                    "microflow.agent.openclaw-state-dir", DATABASE.resolveSibling("missing-state").toString(),
                    "microflow.seed.demo-enabled", "false",
                    "microflow.jwt.secret", "calendar-protocol-test-jwt-secret-with-entropy",
                    "microflow.crypto.secret", "ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA=",
                    "microflow.agent.mock-plan", """
                        {"turns":[{"toolCalls":[{"callId":"calendar-wire","toolKey":"calendar.create_event","input":{
                          "summary":"Protocol review","start":"2026-11-24T09:00:00+08:00","end":"2026-11-24T10:30:00+08:00"}}]},
                          {"text":"Calendar operation reviewed."}]}
                        """);
        }
    }

    @Test void approvedEventReachesCalendarWithUtcTimes() throws Exception {
        try (var peer = new DavServer(false, 201)) {
            var run = waitingRun("CALDAV", peer);
            var before = Instant.now().minusSeconds(2);
            decide(run, "APPROVE");
            awaitStatus(run.owner(), run.id(), "SUCCEEDED");
            assertThat(peer.requests).hasSize(1);
            var request = peer.requests.getFirst();
            assertThat(request.method()).isEqualTo("PUT");
            assertThat(request.contentType()).isEqualTo("text/calendar; charset=utf-8");
            assertThat(request.body()).contains("DTSTART:20261124T010000Z\r\n", "DTEND:20261124T023000Z\r\n",
                    "SUMMARY:Protocol review\r\n", "BEGIN:VCALENDAR\r\n", "END:VCALENDAR\r\n");
            var stamp = request.body().lines().filter(line -> line.startsWith("DTSTAMP:")).findFirst().orElseThrow().substring(8);
            var instant = DateTimeFormatter.ofPattern("uuuuMMdd'T'HHmmssX").withZone(ZoneOffset.UTC).parse(stamp, Instant::from);
            assertThat(instant).isBetween(before, Instant.now().plusSeconds(2));
            var uid = request.body().lines().filter(line -> line.startsWith("UID:")).findFirst().orElseThrow().substring(4);
            assertThat(request.target()).isEqualTo("/calendar/" + uid + ".ics");
        }
    }

    @Test void calendarBodyAcceptedWithoutReplyIsUnknownAndCannotRetry() throws Exception {
        try (var peer = new DavServer(true, 201)) {
            var run = waitingRun("CALDAV", peer);
            decide(run, "APPROVE");
            assertUnknownAndRefusedRetry(run, peer);
            assertThat(peer.requests.getFirst().body()).contains("SUMMARY:Protocol review\r\n");
        }
    }

    @Test void rejectedCalendarApprovalSendsNoPut() throws Exception {
        try (var peer = new DavServer(false, 201)) {
            var run = waitingRun("CALDAV", peer);
            decide(run, "REJECT");
            awaitStatus(run.owner(), run.id(), "SUCCEEDED");
            assertThat(peer.requests).isEmpty();
        }
    }
}
