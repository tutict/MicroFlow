package com.microflow.bootstrap.schema;

import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.JarURLConnection;
import java.net.URISyntaxException;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;
import com.microflow.common.jdbc.JdbcTemplate;

@ApplicationScoped
public class SchemaMaintenanceInitializer {

    private static final String MIGRATION_CLASSPATH_ROOT = "db/migration";
    private static final String MIGRATION_INDEX = MIGRATION_CLASSPATH_ROOT + "/migrations.list";
    private static final Pattern MIGRATION_PATTERN = Pattern.compile("^V(\\d+)__.*\\.sql$");

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
        ensureConnectorDirectionColumns();
        initialized = true;
    }

    private void applySchemaScripts() {
        for (var script : discoverMigrationScripts()) {
            executeScript(script);
        }
    }

    /**
     * Loads registered migrations without treating a classpath URL as a filesystem
     * directory. The index also works in JARs without directory entries and in native
     * images where resources cannot be enumerated.
     *
     * <p>For expanded directories and JARs, the actual inventory must match the index,
     * so a forgotten registration fails startup. All registered resources are checked
     * before SQL runs. Native packaging must include {@code db/migration/**}; the
     * expanded-resource regression checks the source inventory before packaging.
     */
    private List<String> discoverMigrationScripts() {
        var loader = Thread.currentThread().getContextClassLoader();
        var index = loader.getResource(MIGRATION_INDEX);
        if (index == null) {
            throw new IllegalStateException("Schema migration index not found: " + MIGRATION_INDEX);
        }
        var discovered = new ArrayList<String>();
        var names = new LinkedHashSet<String>();
        var versions = new HashSet<Integer>();
        try (var reader = new BufferedReader(new InputStreamReader(
                index.openStream(), StandardCharsets.UTF_8))) {
            for (var line : reader.lines().toList()) {
                var script = line.strip();
                if (script.isEmpty() || script.startsWith("#")) {
                    continue;
                }
                if (!names.add(script) || !versions.add(versionOf(script))) {
                    throw new IllegalStateException("Duplicate schema migration registration: " + script);
                }
                var resource = MIGRATION_CLASSPATH_ROOT + "/" + script;
                try (var stream = loader.getResourceAsStream(resource)) {
                    if (stream == null) {
                        throw new IllegalStateException("Schema resource not found: " + resource);
                    }
                }
                discovered.add(script);
            }
            validateMigrationInventory(index, names);
        } catch (IOException | URISyntaxException exception) {
            throw new IllegalStateException("Unable to read schema migration index " + MIGRATION_INDEX, exception);
        }
        if (discovered.isEmpty()) {
            throw new IllegalStateException(
                    "No schema migration scripts registered in " + MIGRATION_INDEX);
        }
        discovered.sort(SchemaMaintenanceInitializer::compareByVersion);
        return List.copyOf(discovered);
    }

    private void validateMigrationInventory(URL index, Set<String> registered)
            throws IOException, URISyntaxException {
        var available = new LinkedHashSet<String>();
        if ("file".equals(index.getProtocol())) {
            try (var files = Files.list(Path.of(index.toURI()).getParent())) {
                files.filter(Files::isRegularFile)
                        .map(path -> path.getFileName().toString())
                        .filter(name -> MIGRATION_PATTERN.matcher(name).matches())
                        .sorted()
                        .forEach(available::add);
            }
        } else if ("jar".equals(index.getProtocol())) {
            var connection = (JarURLConnection) index.openConnection();
            connection.setUseCaches(false);
            var prefix = MIGRATION_CLASSPATH_ROOT + "/";
            try (var jar = connection.getJarFile()) {
                jar.stream().filter(entry -> !entry.isDirectory())
                        .map(entry -> entry.getName())
                        .filter(name -> name.startsWith(prefix))
                        .map(name -> name.substring(prefix.length()))
                        .filter(name -> MIGRATION_PATTERN.matcher(name).matches())
                        .sorted()
                        .forEach(available::add);
            }
        } else {
            // Native resource URLs do not expose an enumerable directory/archive.
            // The index and preflight resource checks remain authoritative there.
            return;
        }
        available.removeAll(registered);
        if (!available.isEmpty()) {
            throw new IllegalStateException("Unregistered schema migration scripts: " + String.join(", ", available));
        }
    }

    private static int compareByVersion(String left, String right) {
        return Integer.compare(versionOf(left), versionOf(right));
    }

    private static int versionOf(String script) {
        var matcher = MIGRATION_PATTERN.matcher(script);
        if (!matcher.matches()) {
            throw new IllegalStateException("Invalid schema migration registration: " + script);
        }
        try {
            return Integer.parseInt(matcher.group(1));
        } catch (NumberFormatException exception) {
            throw new IllegalStateException("Invalid schema migration version: " + script, exception);
        }
    }

    private void executeScript(String scriptName) {
        var resource = MIGRATION_CLASSPATH_ROOT + "/" + scriptName;
        try (var stream = Thread.currentThread().getContextClassLoader()
                .getResourceAsStream(resource)) {
            if (stream == null) {
                throw new IllegalStateException("Schema resource not found: " + resource);
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
            throw new IllegalStateException("Unable to execute schema script " + scriptName, ex);
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

    /**
     * Adds the connector direction flags to databases created before they
     * existed.
     *
     * <p>Migration scripts replay idempotently, but {@code CREATE TABLE IF NOT
     * EXISTS} does nothing to a table that already exists, so an older
     * {@code agent_connectors} would silently keep missing these columns and every
     * connector read would fail. A {@code PRAGMA} check is the only reliable way
     * to express "add it if this database predates it".
     */
    private void ensureConnectorDirectionColumns() {
        var columns = jdbcTemplate.query(
                "PRAGMA table_info(agent_connectors)",
                (rs, rowNum) -> rs.getString("name")
        );
        if (columns.isEmpty()) {
            return;
        }
        if (!containsIgnoreCase(columns, "read_enabled")) {
            jdbcTemplate.execute(
                    "ALTER TABLE agent_connectors ADD COLUMN read_enabled INTEGER NOT NULL DEFAULT 1");
        }
        if (!containsIgnoreCase(columns, "write_enabled")) {
            jdbcTemplate.execute(
                    "ALTER TABLE agent_connectors ADD COLUMN write_enabled INTEGER NOT NULL DEFAULT 1");
        }
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
