package com.microflow.bootstrap.schema;

import jakarta.annotation.PostConstruct;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
public class SchemaMaintenanceInitializer {

    private final JdbcTemplate jdbcTemplate;

    public SchemaMaintenanceInitializer(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @PostConstruct
    void ensureCompatibilityColumns() {
        ensureAgentRoleStrategyColumn();
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
