package com.microflow.bootstrap.schema;

import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;

@ApplicationScoped
public class SchemaMaintenanceInitializer {

    private final JdbcTemplate jdbcTemplate;
    private boolean initialized;

    public SchemaMaintenanceInitializer(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    void initialize(@Observes StartupEvent event) {
        initializeSchema();
    }

    public synchronized void initializeSchema() {
        if (initialized) {
            return;
        }
        applySchemaScripts();
        ensureAgentRoleStrategyColumn();
        initialized = true;
    }

    private void applySchemaScripts() {
        for (var script : List.of(
                "db/migration/V1__baseline.sql",
                "db/migration/V2__knowledge_and_workspace_management.sql",
                "db/migration/V3__collaboration_event_history.sql",
                "db/migration/V4__accounting_module.sql"
        )) {
            executeScript(script);
        }
    }

    private void executeScript(String script) {
        try (var stream = Thread.currentThread().getContextClassLoader().getResourceAsStream(script)) {
            if (stream == null) {
                throw new IllegalStateException("Schema resource not found: " + script);
            }
            var sql = new BufferedReader(new InputStreamReader(stream, StandardCharsets.UTF_8))
                    .lines()
                    .reduce("", (left, right) -> left + "\n" + right);
            for (var statement : sql.split(";")) {
                var trimmed = statement.trim();
                if (!trimmed.isEmpty()) {
                    jdbcTemplate.execute(trimmed);
                }
            }
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to execute schema script " + script, ex);
        }
    }

    private void ensureAgentRoleStrategyColumn() {
        var columns = jdbcTemplate.query(
                "PRAGMA table_info(agent_configs)",
                (rs, rowNum) -> rs.getString("name")
        );
        if (containsIgnoreCase(columns, "role_strategy")) {
            return;
        }
        jdbcTemplate.execute("ALTER TABLE agent_configs ADD COLUMN role_strategy TEXT");
    }

    private boolean containsIgnoreCase(List<String> values, String expected) {
        for (var value : values) {
            if (value != null && value.equalsIgnoreCase(expected)) {
                return true;
            }
        }
        return false;
    }
}
