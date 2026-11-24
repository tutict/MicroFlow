package com.microflow.bootstrap.schema;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.io.IOException;
import java.net.URLClassLoader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.jar.JarEntry;
import java.util.jar.JarOutputStream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import com.microflow.common.jdbc.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

class SchemaMaintenancePackagingTest {

    private static final String ROOT = "db/migration/";
    private static final String INDEX = "migrations.list";
    private static final List<String> SCRIPTS = List.of(
            "V1__baseline.sql",
            "V2__knowledge_and_workspace_management.sql",
            "V3__collaboration_event_history.sql",
            "V4__accounting_module.sql",
            "V5__task_workbench.sql",
            "V6__workspace_role_capabilities.sql",
            "V7__task_decision_trail.sql",
            "V8__agent_runtime_harness.sql"
    );

    @TempDir
    Path temporaryDirectory;

    private JdbcTemplate jdbc;

    @BeforeEach
    void createRealDatabase() {
        var dataSource = new DriverManagerDataSource(
                "jdbc:sqlite:" + temporaryDirectory.resolve("schema.db").toAbsolutePath());
        dataSource.setDriverClassName("org.sqlite.JDBC");
        jdbc = new JdbcTemplate(dataSource);
    }

    @Test
    void packagedJarAppliesEveryMigration() throws Exception {
        // A directory URL treated as a Path breaks real JAR initialization.
        try (var loader = jarLoader(migrationResources(), true)) {
            initializeWith(loader);
        }
        assertAllMigrationTables();
    }

    @Test
    void packagedJarWithoutDirectoryEntriesAppliesEveryMigration() throws Exception {
        // JARs need not contain entries for directories; discovery must still run V1-V8.
        try (var loader = jarLoader(migrationResources(), false)) {
            initializeWith(loader);
        }
        assertAllMigrationTables();
    }

    @Test
    void expandedProductionResourcesApplyEveryMigration() throws Exception {
        // Exercise the actual resource inventory so future unregistered migrations fail here.
        var resources = Path.of("src/main/resources").toAbsolutePath();
        try (var loader = new URLClassLoader(new java.net.URL[]{resources.toUri().toURL()}, null)) {
            initializeWith(loader);
        }
        assertAllMigrationTables();
    }

    @Test
    void packagedJarPreservesLegacyRowsAndAddsMissingColumns() throws Exception {
        seedLegacyDatabase();
        try (var loader = jarLoader(migrationResources(), true)) {
            initializeWith(loader);
            initializeWith(loader);
        }
        assertLegacyRowsPreserved();
    }

    @Test
    void expandedResourcesPreserveLegacyRowsAndExistingDirectionChoices() throws Exception {
        seedLegacyDatabase();
        jdbc.execute("ALTER TABLE agent_connectors ADD COLUMN read_enabled INTEGER NOT NULL DEFAULT 1");
        jdbc.update("UPDATE agent_connectors SET read_enabled = 0 WHERE id = 'connector-old'");
        try (var loader = expandedLoader(migrationResources())) {
            initializeWith(loader);
        }
        assertLegacyRowsPreserved(0, 1);
        jdbc.update("UPDATE agent_connectors SET write_enabled = 0 WHERE id = 'connector-old'");
        try (var loader = expandedLoader(migrationResources())) {
            initializeWith(loader);
        }
        assertLegacyRowsPreserved(0, 0);
    }

    @Test
    void missingRegisteredResourceFailsBeforeChangingDatabase() throws Exception {
        // A stale/incomplete package must fail explicitly, never silently stop at V7.
        var resources = migrationResources();
        resources.remove(ROOT + "V8__agent_runtime_harness.sql");
        try (var loader = expandedLoader(resources)) {
            assertThatThrownBy(() -> initializeWith(loader))
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining("V8__agent_runtime_harness.sql");
        }
        assertNoTablesCreated();
    }

    @Test
    void unregisteredMigrationInJarFailsBeforeChangingDatabase() throws Exception {
        // Adding SQL without registering it must not report a successful startup.
        var resources = migrationResources();
        resources.put(ROOT + "V9__forgotten.sql", "CREATE TABLE forgotten (id TEXT);".getBytes(StandardCharsets.UTF_8));
        try (var loader = jarLoader(resources, false)) {
            assertThatThrownBy(() -> initializeWith(loader))
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining("V9__forgotten.sql");
        }
        assertNoTablesCreated();
    }

    @Test
    void registeredMigrationsExecuteInNumericOrder() throws Exception {
        // Lexical/index order would run V10 before V9 and fail to create/insert correctly.
        var resources = migrationResources();
        resources.put(ROOT + INDEX, ("V10__insert.sql\n" + String.join("\n", SCRIPTS)
                + "\nV9__create.sql\n").getBytes(StandardCharsets.UTF_8));
        resources.put(ROOT + "V9__create.sql", "CREATE TABLE migration_order (value TEXT);".getBytes(StandardCharsets.UTF_8));
        resources.put(ROOT + "V10__insert.sql", "INSERT INTO migration_order VALUES ('numeric-order');".getBytes(StandardCharsets.UTF_8));
        try (var loader = jarLoader(resources, false)) {
            initializeWith(loader);
        }
        assertThat(jdbc.queryForObject("SELECT value FROM migration_order", String.class)).isEqualTo("numeric-order");
    }

    @Test
    void missingMigrationIndexFailsWithResourceName() throws Exception {
        var resources = migrationResources();
        resources.remove(ROOT + INDEX);
        try (var loader = expandedLoader(resources)) {
            assertThatThrownBy(() -> initializeWith(loader))
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining(ROOT + INDEX);
        }
        assertNoTablesCreated();
    }

    private void initializeWith(ClassLoader loader) {
        var thread = Thread.currentThread();
        var previous = thread.getContextClassLoader();
        thread.setContextClassLoader(loader);
        try {
            new SchemaMaintenanceInitializer(jdbc).initializeSchema();
        } finally {
            thread.setContextClassLoader(previous);
        }
    }

    private Map<String, byte[]> migrationResources() throws IOException {
        var resources = new LinkedHashMap<String, byte[]>();
        // Deliberately reverse physical entry order; version order belongs to production code.
        for (var script : SCRIPTS.reversed()) {
            resources.put(ROOT + script, Files.readAllBytes(Path.of("src/main/resources", ROOT + script)));
        }
        resources.put(ROOT + INDEX, (String.join("\n", SCRIPTS) + "\n").getBytes(StandardCharsets.UTF_8));
        return resources;
    }

    private URLClassLoader expandedLoader(Map<String, byte[]> resources) throws IOException {
        var directory = Files.createTempDirectory(temporaryDirectory, "expanded-");
        for (var resource : resources.entrySet()) {
            var target = directory.resolve(resource.getKey());
            Files.createDirectories(target.getParent());
            Files.write(target, resource.getValue());
        }
        return new URLClassLoader(new java.net.URL[]{directory.toUri().toURL()}, null);
    }

    private URLClassLoader jarLoader(Map<String, byte[]> resources, boolean directoryEntries) throws IOException {
        var jar = Files.createTempFile(temporaryDirectory, "migrations-", ".jar");
        try (var output = new JarOutputStream(Files.newOutputStream(jar))) {
            if (directoryEntries) {
                output.putNextEntry(new JarEntry("db/"));
                output.closeEntry();
                output.putNextEntry(new JarEntry(ROOT));
                output.closeEntry();
            }
            for (var resource : resources.entrySet()) {
                output.putNextEntry(new JarEntry(resource.getKey()));
                output.write(resource.getValue());
                output.closeEntry();
            }
        }
        return new URLClassLoader(new java.net.URL[]{jar.toUri().toURL()}, null);
    }

    private void assertAllMigrationTables() {
        var tables = jdbc.queryForList("SELECT name FROM sqlite_master WHERE type = 'table'", String.class);
        assertThat(tables).contains(
                "users", "workspaces", "workspace_members", "channels", "messages", "message_mentions",
                "agent_configs", "agent_runs", "refresh_tokens", "knowledge_documents", "knowledge_chunks",
                "collaboration_events", "accounting_accounts", "accounting_vouchers", "accounting_voucher_lines",
                "task_projects", "tasks", "task_activity", "task_decisions", "agent_run_sessions", "agent_run_events",
                "agent_run_steps", "agent_run_messages", "agent_context_sources", "agent_approvals", "agent_artifacts",
                "agent_tool_invocations", "agent_provider_capabilities", "agent_connectors", "agent_connector_grants");
        assertThat(jdbc.queryForList("PRAGMA table_info(agent_configs)").stream()
                .map(row -> row.get("name"))).contains("role_strategy");
        assertThat(jdbc.queryForList("PRAGMA table_info(agent_connectors)").stream()
                .map(row -> row.get("name"))).contains("read_enabled", "write_enabled");
    }

    private void assertNoTablesCreated() {
        assertThat(jdbc.queryForObject("SELECT count(*) FROM sqlite_master WHERE type = 'table'", Integer.class))
                .isZero();
    }

    private void seedLegacyDatabase() throws IOException {
        for (var script : SCRIPTS) {
            var sql = Files.readString(Path.of("src/main/resources", ROOT + script))
                    .replace("    role_strategy TEXT,", "")
                    .replace("    read_enabled INTEGER NOT NULL DEFAULT 1,", "")
                    .replace("    write_enabled INTEGER NOT NULL DEFAULT 1,", "");
            for (var statement : sql.split(";")) {
                if (!statement.isBlank()) {
                    jdbc.execute(statement);
                }
            }
        }
        jdbc.execute("INSERT INTO users VALUES ('user-old', 'old@example.test', 'hash-old', 'User old', 'ACTIVE', 'created', 'updated')");
        jdbc.execute("INSERT INTO workspaces VALUES ('workspace-old', 'Workspace old', 'user-old', 'created')");
        jdbc.execute("INSERT INTO workspace_members VALUES ('workspace-old', 'user-old', ' owner ', 'joined')");
        jdbc.execute("INSERT INTO channels VALUES ('channel-old', 'workspace-old', 'Channel old', 'ROOM', 'created')");
        jdbc.execute("INSERT INTO messages (id, workspace_id, channel_id, sender_type, ciphertext, iv, key_version, created_at) VALUES ('message-old', 'workspace-old', 'channel-old', 'USER', X'0102', X'0304', 1, 'created')");
        jdbc.execute("INSERT INTO agent_configs (id, workspace_id, agent_key, provider, endpoint_url, credential_ciphertext, credential_iv, credential_key_version, created_at, updated_at) VALUES ('config-old', 'workspace-old', 'agent-old', 'OPENAI', 'https://old.invalid', X'0506', X'0708', 1, 'created', 'updated')");
        jdbc.execute("INSERT INTO agent_runs (id, workspace_id, channel_id, trigger_message_id, agent_key, provider, status, created_at) VALUES ('run-old', 'workspace-old', 'channel-old', 'message-old', 'agent-old', 'OPENAI', 'SUCCEEDED', 'created')");
        jdbc.execute("INSERT INTO tasks (id, workspace_id, title, creator_user_id, created_at, updated_at) VALUES ('task-old', 'workspace-old', 'Task old', 'user-old', 'created', 'updated')");
        jdbc.execute("INSERT INTO task_decisions (id, workspace_id, task_id, sequence_no, summary, decided_by_user_id, created_at) VALUES ('decision-old', 'workspace-old', 'task-old', 1, 'Decision old', 'user-old', 'created')");
        jdbc.execute("INSERT INTO agent_run_sessions (id, workspace_id, task_id, initiator_user_id, agent_key, run_kind, status, goal, created_at, updated_at) VALUES ('session-old', 'workspace-old', 'task-old', 'user-old', 'agent-old', 'TASK', 'SUCCEEDED', 'Goal old', 'created', 'updated')");
        jdbc.execute("INSERT INTO agent_run_events (id, session_id, workspace_id, seq, event_type, payload_json, created_at) VALUES ('event-old', 'session-old', 'workspace-old', 1, 'FINISHED', '{\"old\":true}', 'created')");
        jdbc.execute("INSERT INTO agent_run_steps (id, session_id, seq, step_kind, status, title, started_at) VALUES ('step-old', 'session-old', 1, 'TOOL', 'SUCCEEDED', 'Step old', 'started')");
        jdbc.execute("INSERT INTO agent_run_messages (id, session_id, seq, role, content, created_at) VALUES ('runtime-message-old', 'session-old', 1, 'assistant', 'Content old', 'created')");
        jdbc.execute("INSERT INTO agent_context_sources (id, session_id, workspace_id, source_type, label, created_at) VALUES ('source-old', 'session-old', 'workspace-old', 'TASK', 'Source old', 'created')");
        jdbc.execute("INSERT INTO agent_approvals (id, session_id, workspace_id, tool_key, action, risk_level, status, created_at) VALUES ('approval-old', 'session-old', 'workspace-old', 'mail.send', 'send', 'HIGH', 'APPROVED', 'created')");
        jdbc.execute("INSERT INTO agent_artifacts (id, session_id, workspace_id, artifact_kind, title, created_at) VALUES ('artifact-old', 'session-old', 'workspace-old', 'DRAFT', 'Artifact old', 'created')");
        jdbc.execute("INSERT INTO agent_tool_invocations (id, session_id, workspace_id, tool_key, idempotency_key, status, risk_level, created_at) VALUES ('invocation-old', 'session-old', 'workspace-old', 'mail.send', 'key-old', 'SUCCEEDED', 'HIGH', 'created')");
        jdbc.execute("INSERT INTO agent_connectors (id, workspace_id, owner_user_id, connector_kind, name, config_json, secret_ciphertext, secret_iv, secret_key_version, sharing_scope, status, created_at, updated_at) VALUES ('connector-old', 'workspace-old', 'user-old', 'WEBDAV', 'Connector old', '{\"url\":\"https://old.invalid\"}', X'090A', X'0B0C', 1, 'PRIVATE', 'ACTIVE', 'created', 'updated')");
        jdbc.execute("INSERT INTO agent_connector_grants (id, connector_id, grantee_type, grantee_ref, created_at) VALUES ('grant-old', 'connector-old', 'USER', 'user-old', 'created')");
    }

    private void assertLegacyRowsPreserved() {
        assertLegacyRowsPreserved(1, 1);
    }

    private void assertLegacyRowsPreserved(int readEnabled, int writeEnabled) {
        assertAllMigrationTables();
        assertThat(jdbc.queryForObject("SELECT email FROM users WHERE id = 'user-old'", String.class)).isEqualTo("old@example.test");
        assertThat(jdbc.queryForObject("SELECT name FROM workspaces WHERE id = 'workspace-old'", String.class)).isEqualTo("Workspace old");
        assertThat(jdbc.queryForObject("SELECT role FROM workspace_members WHERE user_id = 'user-old'", String.class)).isEqualTo("OWNER");
        assertThat(jdbc.queryForObject("SELECT name FROM channels WHERE id = 'channel-old'", String.class)).isEqualTo("Channel old");
        assertThat(jdbc.queryForObject("SELECT hex(ciphertext) FROM messages WHERE id = 'message-old'", String.class)).isEqualTo("0102");
        assertThat(jdbc.queryForObject("SELECT hex(credential_ciphertext) FROM agent_configs WHERE id = 'config-old'", String.class)).isEqualTo("0506");
        assertThat(jdbc.queryForObject("SELECT role_strategy FROM agent_configs WHERE id = 'config-old'", String.class)).isNull();
        assertThat(jdbc.queryForObject("SELECT status FROM agent_runs WHERE id = 'run-old'", String.class)).isEqualTo("SUCCEEDED");
        assertThat(jdbc.queryForObject("SELECT title FROM tasks WHERE id = 'task-old'", String.class)).isEqualTo("Task old");
        assertThat(jdbc.queryForObject("SELECT summary FROM task_decisions WHERE id = 'decision-old'", String.class)).isEqualTo("Decision old");
        assertThat(jdbc.queryForObject("SELECT goal FROM agent_run_sessions WHERE id = 'session-old'", String.class)).isEqualTo("Goal old");
        assertThat(jdbc.queryForObject("SELECT payload_json FROM agent_run_events WHERE id = 'event-old'", String.class)).isEqualTo("{\"old\":true}");
        assertThat(jdbc.queryForObject("SELECT title FROM agent_run_steps WHERE id = 'step-old'", String.class)).isEqualTo("Step old");
        assertThat(jdbc.queryForObject("SELECT content FROM agent_run_messages WHERE id = 'runtime-message-old'", String.class)).isEqualTo("Content old");
        assertThat(jdbc.queryForObject("SELECT label FROM agent_context_sources WHERE id = 'source-old'", String.class)).isEqualTo("Source old");
        assertThat(jdbc.queryForObject("SELECT status FROM agent_approvals WHERE id = 'approval-old'", String.class)).isEqualTo("APPROVED");
        assertThat(jdbc.queryForObject("SELECT title FROM agent_artifacts WHERE id = 'artifact-old'", String.class)).isEqualTo("Artifact old");
        assertThat(jdbc.queryForObject("SELECT idempotency_key FROM agent_tool_invocations WHERE id = 'invocation-old'", String.class)).isEqualTo("key-old");
        assertThat(jdbc.queryForObject("SELECT hex(secret_ciphertext) FROM agent_connectors WHERE id = 'connector-old'", String.class)).isEqualTo("090A");
        assertThat(jdbc.queryForObject("SELECT config_json FROM agent_connectors WHERE id = 'connector-old'", String.class)).isEqualTo("{\"url\":\"https://old.invalid\"}");
        assertThat(jdbc.queryForObject("SELECT read_enabled FROM agent_connectors WHERE id = 'connector-old'", Integer.class)).isEqualTo(readEnabled);
        assertThat(jdbc.queryForObject("SELECT write_enabled FROM agent_connectors WHERE id = 'connector-old'", Integer.class)).isEqualTo(writeEnabled);
        assertThat(jdbc.queryForObject("SELECT grantee_ref FROM agent_connector_grants WHERE id = 'grant-old'", String.class)).isEqualTo("user-old");
    }
}
