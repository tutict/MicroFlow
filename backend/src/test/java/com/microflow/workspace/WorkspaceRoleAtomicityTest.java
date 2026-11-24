package com.microflow.workspace;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.microflow.bootstrap.schema.SchemaMaintenanceInitializer;
import com.microflow.common.error.AccessDeniedException;
import com.microflow.common.error.ConcurrentModificationException;
import com.microflow.common.jdbc.JdbcTemplate;
import com.microflow.workspace.application.service.DefaultWorkspaceManagementService;
import com.microflow.workspace.domain.model.WorkspaceMemberSummary;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import com.microflow.workspace.infrastructure.security.DefaultWorkspaceAccessGuard;
import java.nio.file.Path;
import java.time.Clock;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import javax.sql.DataSource;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.sqlite.SQLiteDataSource;

/** Pauses before actual SQLite writes, after the service has read its role snapshots. */
class WorkspaceRoleAtomicityTest {

    @TempDir
    Path directory;

    private final ExecutorService writers = Executors.newFixedThreadPool(2);
    private final List<WriteGate> gates = new ArrayList<>();
    private GatedJdbcTemplate jdbc;
    private DefaultWorkspaceManagementService service;

    @BeforeEach
    void initializeDatabase() {
        var dataSource = new SQLiteDataSource();
        dataSource.setUrl("jdbc:sqlite:" + directory.resolve("roles.db"));
        dataSource.setBusyTimeout(5_000);
        jdbc = new GatedJdbcTemplate(dataSource);
        new SchemaMaintenanceInitializer(jdbc).initializeSchema();
        var repository = new JdbcWorkspaceRepository(jdbc, null, Clock.systemUTC());
        var guard = new DefaultWorkspaceAccessGuard(repository, (workspaceId, taskId) -> null);
        service = new DefaultWorkspaceManagementService(repository, null, null, guard);
        jdbc.update("INSERT INTO users VALUES ('A', 'a@example.test', 'hash', 'A', 'ACTIVE', 'created', 'updated')");
        jdbc.update("INSERT INTO users VALUES ('B', 'b@example.test', 'hash', 'B', 'ACTIVE', 'created', 'updated')");
        jdbc.update("INSERT INTO users VALUES ('C', 'c@example.test', 'hash', 'C', 'ACTIVE', 'created', 'updated')");
        jdbc.update("INSERT INTO workspaces VALUES ('workspace', 'Roles', 'A', 'created')");
    }

    @AfterEach
    void releaseWriters() throws InterruptedException {
        for (var gate : gates) {
            gate.release.countDown();
        }
        writers.shutdownNow();
        assertThat(writers.awaitTermination(10, TimeUnit.SECONDS)).isTrue();
    }

    @Test
    void staleNonOwnerUpdateCannotDemoteTheNewlyPromotedLastOwner() throws Exception {
        // B15: the old non-owner branch would demote B after B has become the sole owner.
        member("A", "OWNER");
        member("B", "OPERATOR");
        var gate = gate();
        var oldRequest = pausedChange(gate, "A", "B", "VIEWER");
        gate.awaitReady();

        assertThat(change("A", "B", "OWNER").role()).isEqualTo("OWNER");
        assertThat(change("B", "A", "MAINTAINER").role()).isEqualTo("MAINTAINER");
        assertThat(ownerCount()).isEqualTo(1);
        gate.release.countDown();
        var result = oldRequest.get(10, TimeUnit.SECONDS);

        assertThat(role("A")).isEqualTo("MAINTAINER");
        assertThat(role("B")).as("the promoted last owner must survive the stale request").isEqualTo("OWNER");
        assertThat(ownerCount()).isEqualTo(1);
        assertRejectedStaleRequest(result);
    }

    @Test
    void actorLosingOwnerRoleCannotApplyAnAlreadyValidatedChange() throws Exception {
        // Authorization checked only before the write permits a demoted actor to change C.
        member("A", "OWNER");
        member("B", "OWNER");
        member("C", "OPERATOR");
        var gate = gate();
        var oldRequest = pausedChange(gate, "A", "C", "VIEWER");
        gate.awaitReady();

        assertThat(change("B", "A", "MAINTAINER").role()).isEqualTo("MAINTAINER");
        gate.release.countDown();
        var result = oldRequest.get(10, TimeUnit.SECONDS);

        assertThat(role("C")).as("revoked OWNER authorization must cause zero target changes").isEqualTo("OPERATOR");
        assertThat(role("A")).isEqualTo("MAINTAINER");
        assertThat(role("B")).isEqualTo("OWNER");
        assertRejectedStaleRequest(result);
    }

    @Test
    void staleTargetRoleCannotOverwriteAnotherOwnersCompletedChange() throws Exception {
        // Actor A stays authorized, so only a target-role predicate prevents a lost update.
        member("A", "OWNER");
        member("B", "OPERATOR");
        member("C", "OWNER");
        var gate = gate();
        var oldRequest = pausedChange(gate, "A", "B", "VIEWER");
        gate.awaitReady();

        assertThat(change("C", "B", "MAINTAINER").role()).isEqualTo("MAINTAINER");
        gate.release.countDown();
        var result = oldRequest.get(10, TimeUnit.SECONDS);

        assertThat(role("B")).isEqualTo("MAINTAINER");
        assertThat(ownerCount()).isEqualTo(2);
        assertThat(result.failure()).isInstanceOf(ConcurrentModificationException.class);
        assertThat(result.member()).isNull();
    }

    @Test
    void concurrentOwnersDemotingEachOtherHaveOnlyOneAuthorizedWinner() throws Exception {
        // Both service snapshots see two owners; the SQL write must decide the single winner.
        member("A", "OWNER");
        member("B", "OWNER");
        var firstGate = gate();
        var secondGate = gate();
        var first = pausedChange(firstGate, "A", "B", "MAINTAINER");
        var second = pausedChange(secondGate, "B", "A", "MAINTAINER");
        firstGate.awaitReady();
        secondGate.awaitReady();
        firstGate.release.countDown();
        secondGate.release.countDown();
        var outcomes = List.of(first.get(10, TimeUnit.SECONDS), second.get(10, TimeUnit.SECONDS));

        assertThat(ownerCount()).isEqualTo(1);
        assertThat(List.of(role("A"), role("B"))).containsExactlyInAnyOrder("OWNER", "MAINTAINER");
        assertThat(outcomes.stream().filter(outcome -> outcome.failure() == null).toList()).hasSize(1);
        assertThat(outcomes.stream().filter(outcome -> outcome.failure() != null).toList())
                .singleElement().satisfies(WorkspaceRoleAtomicityTest::assertRejectedStaleRequest);
    }

    @Test
    void ordinaryChangesKeepOwnerAuthorizationAndSelfDemotionRules() {
        member("A", "OWNER");
        member("B", "OPERATOR");
        assertThat(change("A", "B", "VIEWER").role()).isEqualTo("VIEWER");
        assertThat(change("A", "B", "MAINTAINER").role()).isEqualTo("MAINTAINER");
        assertThatThrownBy(() -> change("B", "A", "VIEWER")).isInstanceOf(AccessDeniedException.class);
        assertThatThrownBy(() -> change("A", "A", "MAINTAINER")).isInstanceOf(IllegalArgumentException.class);
        assertThat(change("A", "B", "OWNER").role()).isEqualTo("OWNER");
        assertThat(change("B", "A", "MAINTAINER").role()).isEqualTo("MAINTAINER");
        assertThat(ownerCount()).isEqualTo(1);
        assertThat(role("B")).isEqualTo("OWNER");
    }

    private void member(String userId, String role) {
        jdbc.update("INSERT INTO workspace_members VALUES ('workspace', ?, ?, 'joined')", userId, role);
    }

    private WorkspaceMemberSummary change(String actor, String target, String role) {
        return service.changeMemberRole(actor, "workspace", target, role);
    }

    private String role(String userId) {
        return jdbc.queryForObject("SELECT role FROM workspace_members WHERE workspace_id = 'workspace' AND user_id = ?",
                String.class, userId);
    }

    private int ownerCount() {
        return jdbc.queryForObject("SELECT COUNT(*) FROM workspace_members WHERE workspace_id = 'workspace' AND role = 'OWNER'",
                Integer.class);
    }

    private WriteGate gate() {
        var gate = new WriteGate();
        gates.add(gate);
        return gate;
    }

    private Future<ChangeOutcome> pausedChange(WriteGate gate, String actor, String target, String role) {
        return writers.submit(() -> {
            jdbc.pauseNextWrite(gate);
            try {
                return new ChangeOutcome(change(actor, target, role), null);
            } catch (RuntimeException failure) {
                return new ChangeOutcome(null, failure);
            } finally {
                jdbc.clearPause();
            }
        });
    }

    private static void assertRejectedStaleRequest(ChangeOutcome result) {
        assertThat(result.failure()).isInstanceOfAny(ConcurrentModificationException.class, AccessDeniedException.class);
        assertThat(result.member()).isNull();
    }

    private record ChangeOutcome(WorkspaceMemberSummary member, RuntimeException failure) {
    }

    private static final class WriteGate {
        private final CountDownLatch ready = new CountDownLatch(1);
        private final CountDownLatch release = new CountDownLatch(1);

        void awaitReady() throws InterruptedException {
            assertThat(ready.await(10, TimeUnit.SECONDS)).as("request must reach the JDBC write boundary").isTrue();
        }

        void pause() {
            ready.countDown();
            try {
                if (!release.await(10, TimeUnit.SECONDS)) {
                    throw new AssertionError("Timed out waiting to release the SQLite write");
                }
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                throw new AssertionError("Interrupted at the SQLite write boundary", exception);
            }
        }
    }

    /** All queries/writes remain real; only the timing before a write is controlled. */
    private static final class GatedJdbcTemplate extends JdbcTemplate {
        private final ThreadLocal<WriteGate> nextWrite = new ThreadLocal<>();

        GatedJdbcTemplate(DataSource dataSource) {
            super(dataSource);
        }

        void pauseNextWrite(WriteGate gate) {
            nextWrite.set(gate);
        }

        void clearPause() {
            nextWrite.remove();
        }

        @Override
        public int update(String sql, Object... parameters) {
            var gate = nextWrite.get();
            if (gate != null) {
                nextWrite.remove();
                gate.pause();
            }
            return super.update(sql, parameters);
        }
    }
}
