package com.microflow.common.jdbc;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.io.PrintWriter;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Proxy;
import java.math.BigDecimal;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Types;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.logging.Logger;
import javax.sql.DataSource;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.sqlite.SQLiteDataSource;

class JdbcTemplateTest {

    @TempDir
    Path directory;

    private JdbcTemplate jdbc;
    private TrackedDataSource dataSource;

    @BeforeEach
    void createDatabase() {
        var sqlite = new SQLiteDataSource();
        sqlite.setUrl("jdbc:sqlite:" + directory.resolve("jdbc.db"));
        dataSource = new TrackedDataSource(sqlite);
        jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("CREATE TABLE entries (id INTEGER PRIMARY KEY, name TEXT UNIQUE NOT NULL, amount NUMERIC, payload BLOB, note TEXT)");
    }

    @Test
    void preparedParametersPreserveNullableTextNumbersDecimalAndBlob() throws Exception {
        // String interpolation, generic BLOB binding or lost SQL NULL breaks persisted data.
        var name = "O'Brien'); DROP TABLE entries; --";
        assertThat(jdbc.update("INSERT INTO entries VALUES (?, ?, ?, ?, ?)",
                1, name, new BigDecimal("123.45"), new byte[] {0, 1, -1}, null)).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT name FROM entries WHERE id = ?", String.class, 1)).isEqualTo(name);
        assertThat(jdbc.queryForObject("SELECT id FROM entries", Integer.class)).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT id FROM entries", Long.class)).isEqualTo(1L);
        assertThat(jdbc.queryForObject("SELECT amount FROM entries", BigDecimal.class)).isEqualByComparingTo("123.45");
        assertThat(jdbc.queryForObject("SELECT payload FROM entries", byte[].class)).containsExactly(0, 1, -1);
        assertThat(jdbc.queryForObject("SELECT note FROM entries", String.class)).isNull();
        assertThat(jdbc.queryForObject("SELECT CAST(NULL AS INTEGER)", Integer.class)).isNull();
        assertThat(jdbc.queryForObject("SELECT CAST(NULL AS INTEGER)", Long.class)).isNull();
        assertThat(jdbc.queryForObject("SELECT NULL", BigDecimal.class)).isNull();
        assertThat(jdbc.queryForObject("SELECT NULL", byte[].class)).isNull();
        dataSource.assertClosed();
    }

    @Test
    void queryMapsEveryRowWithZeroBasedNumbersAndAllowsNullResults() throws Exception {
        jdbc.update("INSERT INTO entries(id, name) VALUES (?, ?)", 1, "first");
        jdbc.update("INSERT INTO entries(id, name) VALUES (?, ?)", 2, "second");
        assertThat(jdbc.query("SELECT name FROM entries ORDER BY id", (rs, row) -> row + ":" + rs.getString(1)))
                .containsExactly("0:first", "1:second");
        assertThat(jdbc.query("SELECT name FROM entries ORDER BY id", (rs, row) -> (String) null))
                .containsExactly(null, null);
        assertThat(jdbc.queryForList("SELECT name FROM entries WHERE id > ? ORDER BY id", String.class, 0))
                .containsExactly("first", "second");
        dataSource.assertClosed();
    }

    @Test
    void objectQueryRejectsEmptyAndMultipleRowsForScalarAndMapper() throws Exception {
        assertThatThrownBy(() -> jdbc.queryForObject("SELECT name FROM entries", String.class))
                .isInstanceOf(EmptyResultDataAccessException.class);
        assertThatThrownBy(() -> jdbc.queryForObject("SELECT name FROM entries", (rs, row) -> rs.getString(1)))
                .isInstanceOf(EmptyResultDataAccessException.class);
        jdbc.update("INSERT INTO entries(id, name) VALUES (1, 'one'), (2, 'two')");
        assertThatThrownBy(() -> jdbc.queryForObject("SELECT name FROM entries", String.class))
                .isInstanceOf(IncorrectResultSizeDataAccessException.class)
                .isNotInstanceOf(EmptyResultDataAccessException.class);
        assertThatThrownBy(() -> jdbc.queryForObject("SELECT name FROM entries", (rs, row) -> rs.getString(1)))
                .isInstanceOf(IncorrectResultSizeDataAccessException.class);
        assertThat(jdbc.<String>queryForObject("SELECT name FROM entries WHERE id = 1", (rs, row) -> null)).isNull();
        dataSource.assertClosed();
    }

    @Test
    void scalarQueryRejectsMultipleColumns() throws Exception {
        assertThatThrownBy(() -> jdbc.queryForObject("SELECT 1, 2", Integer.class))
                .isInstanceOf(DataAccessException.class);
        dataSource.assertClosed();
    }

    @Test
    void mapQueryRetainsColumnLabelsOrderNullAndBlob() throws Exception {
        jdbc.update("INSERT INTO entries VALUES (?, ?, ?, ?, ?)", 1, "one", null, new byte[] {2, 3}, null);
        var row = jdbc.queryForList("SELECT name AS DisplayName, note, payload FROM entries WHERE id = ?", 1).getFirst();
        assertThat(row.keySet()).containsExactly("DisplayName", "note", "payload");
        assertThat(row.get("displayname")).isEqualTo("one");
        assertThat(row).containsEntry("note", null);
        assertThat((byte[]) row.get("payload")).containsExactly(2, 3);
        dataSource.assertClosed();
    }

    @Test
    void rowCallbackVisitsEachRowWithoutAdvancingTheCursorItself() throws Exception {
        var ids = new ArrayList<Integer>();
        jdbc.query("SELECT 7 AS id UNION ALL SELECT 8 AS id", rs -> { ids.add(rs.getInt("id")); });
        assertThat(ids).containsExactly(7, 8);
        dataSource.assertClosed();
    }

    @Test
    void resultSetExtractorRunsOnceBeforeFirstRowAndReturnsItsAggregate() throws Exception {
        // Treating an extractor as a row callback skips the first result and loses the aggregate.
        var calls = new AtomicInteger();
        var values = jdbc.query("SELECT ? AS id, 'seven' AS name UNION ALL SELECT ?, 'eight'", rows -> {
            calls.incrementAndGet();
            assertThat(rows.isBeforeFirst()).isTrue();
            assertThat(rows.getRow()).isZero();
            var extracted = new LinkedHashMap<Integer, String>();
            while (rows.next()) {
                extracted.put(rows.getInt("id"), rows.getString("name"));
            }
            return Map.copyOf(extracted);
        }, 7, 8);
        assertThat(calls.get()).isEqualTo(1);
        assertThat(values).containsExactlyInAnyOrderEntriesOf(Map.of(7, "seven", 8, "eight"));
        dataSource.assertClosed();
    }

    @Test
    void resultSetExtractorRunsForEmptyResultsAndPreservesItsReturnValue() throws Exception {
        var calls = new AtomicInteger();
        var value = jdbc.query("SELECT name FROM entries WHERE id = ?", rows -> {
            calls.incrementAndGet();
            assertThat(rows.getRow()).isZero();
            assertThat(rows.next()).isFalse();
            return "empty result";
        }, 99);
        assertThat(calls.get()).isEqualTo(1);
        assertThat(value).isEqualTo("empty result");
        dataSource.assertClosed();
    }

    @Test
    void resultSetExtractorRuntimeFailurePropagatesAndClosesResources() throws Exception {
        var failure = new IllegalStateException("invalid extracted state");
        ResultSetExtractor<String> extractor = rows -> { throw failure; };
        assertThatThrownBy(() -> jdbc.query("SELECT 1", extractor)).isSameAs(failure);
        dataSource.assertClosed();
    }

    @Test
    void preparedStatementCreatorKeepsExplicitBindingAndUpdateCount() throws Exception {
        assertThat(jdbc.update(connection -> {
            var statement = connection.prepareStatement("INSERT INTO entries VALUES (?, ?, ?, ?, ?)");
            statement.setInt(1, 1);
            statement.setString(2, "created");
            statement.setBigDecimal(3, new BigDecimal("42.25"));
            statement.setBytes(4, new byte[] {4, 5});
            statement.setNull(5, Types.VARCHAR);
            return statement;
        })).isEqualTo(1);
        assertThat(jdbc.update("UPDATE entries SET note = ? WHERE id = ?", "saved", 99)).isZero();
        assertThat(jdbc.queryForObject("SELECT amount FROM entries", BigDecimal.class)).isEqualByComparingTo("42.25");
        assertThat(jdbc.queryForObject("SELECT note FROM entries", String.class)).isNull();
        dataSource.assertClosed();
    }

    @Test
    void uniqueAndPrimaryKeyViolationsKeepDuplicateCatchBranches() throws Exception {
        jdbc.update("INSERT INTO entries(id, name) VALUES (1, 'one')");
        assertThatThrownBy(() -> jdbc.update("INSERT INTO entries(id, name) VALUES (2, 'one')"))
                .isInstanceOf(DuplicateKeyException.class).hasCauseInstanceOf(SQLException.class);
        assertThatThrownBy(() -> jdbc.update("INSERT INTO entries(id, name) VALUES (1, 'other')"))
                .isInstanceOf(DuplicateKeyException.class);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM entries", Integer.class)).isEqualTo(1);
        dataSource.assertClosed();
    }

    @Test
    void nonDuplicateConstraintAndSqlErrorsRemainFailures() throws Exception {
        assertThatThrownBy(() -> jdbc.update("INSERT INTO entries(id, name) VALUES (1, NULL)"))
                .isInstanceOf(DataIntegrityViolationException.class).isNotInstanceOf(DuplicateKeyException.class);
        assertThatThrownBy(() -> jdbc.queryForObject("SELECT missing_column FROM entries", String.class))
                .isInstanceOf(DataAccessException.class).hasCauseInstanceOf(SQLException.class);
        assertThatThrownBy(() -> jdbc.execute("invalid SQL"))
                .isInstanceOf(DataAccessException.class);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM entries", Integer.class)).isZero();
        dataSource.assertClosed();
    }

    @Test
    void mapperRuntimeFailurePropagatesUnchangedAndClosesResources() throws Exception {
        // Persisted tool JSON validators throw runtime exceptions; swallowing one hides corruption.
        var invalidData = new IllegalStateException("Invalid persisted tool call data");
        assertThatThrownBy(() -> jdbc.query("SELECT 'invalid'", (rs, row) -> { throw invalidData; }))
                .isSameAs(invalidData);
        dataSource.assertClosed();
    }

    @Test
    void batchUpdateReturnsDriverCountsPerChunkAndBindsDecimals() throws Exception {
        var counts = jdbc.batchUpdate("INSERT INTO entries(id, name, amount) VALUES (?, ?, ?)",
                List.of(1, 2, 3), 2, (statement, id) -> {
                    statement.setInt(1, id);
                    statement.setString(2, "entry-" + id);
                    statement.setBigDecimal(3, new BigDecimal("10.25"));
                });
        assertThat(counts.length).isEqualTo(2);
        assertThat(counts[0]).containsExactly(1, 1);
        assertThat(counts[1]).containsExactly(1);
        assertThat(jdbc.queryForObject("SELECT sum(amount) FROM entries", BigDecimal.class)).isEqualByComparingTo("30.75");
        assertThat(jdbc.batchUpdate("INSERT INTO entries(id, name) VALUES (?, ?)", List.<Integer>of(), 0,
                (statement, id) -> { throw new AssertionError("Empty input must not invoke the setter"); })).isEmpty();
        dataSource.assertClosed();
    }

    @Test
    void batchFailureStopsLaterRowsAndPreservesExistingAutoCommitBoundary() throws Exception {
        // Introducing a transaction or continuing past a failed row changes accounting semantics.
        assertThatThrownBy(() -> jdbc.batchUpdate("INSERT INTO entries(id, name) VALUES (?, ?)",
                List.of(1, 1, 3), 3, (statement, id) -> {
                    statement.setInt(1, id);
                    statement.setString(2, "entry-" + id);
                })).isInstanceOf(DuplicateKeyException.class).hasCauseInstanceOf(SQLException.class);
        assertThat(jdbc.queryForList("SELECT id FROM entries ORDER BY id", Integer.class)).containsExactly(1);
        dataSource.assertClosed();
    }

    @Test
    void batchSetterRuntimeFailureDoesNotExecuteQueuedRows() throws Exception {
        var failure = new IllegalArgumentException("invalid row");
        assertThatThrownBy(() -> jdbc.batchUpdate("INSERT INTO entries(id, name) VALUES (?, ?)",
                List.of(1, 2), 2, (statement, id) -> {
                    if (id == 2) { throw failure; }
                    statement.setInt(1, id);
                    statement.setString(2, "entry-" + id);
                })).isSameAs(failure);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM entries", Integer.class)).isZero();
        dataSource.assertClosed();
    }

    /** Delegates to real SQLite objects and retains them to inspect their real closed state. */
    private static final class TrackedDataSource implements DataSource {
        private final DataSource delegate;
        private final List<Connection> connections = new ArrayList<>();
        private final List<Statement> statements = new ArrayList<>();
        private final List<ResultSet> results = new ArrayList<>();

        private TrackedDataSource(DataSource delegate) { this.delegate = delegate; }

        @Override
        public Connection getConnection() throws SQLException {
            var connection = delegate.getConnection();
            connections.add(connection);
            return (Connection) Proxy.newProxyInstance(Connection.class.getClassLoader(), new Class<?>[] {Connection.class},
                    (proxy, method, args) -> {
                        var value = invoke(connection, method, args);
                        if (value instanceof Statement statement) {
                            statements.add(statement);
                            var type = statement instanceof PreparedStatement ? PreparedStatement.class : Statement.class;
                            return Proxy.newProxyInstance(type.getClassLoader(), new Class<?>[] {type}, (p, m, a) -> {
                                var result = invoke(statement, m, a);
                                if (result instanceof ResultSet rows) { results.add(rows); }
                                return result;
                            });
                        }
                        return value;
                    });
        }

        private static Object invoke(Object target, java.lang.reflect.Method method, Object[] args) throws Throwable {
            try { return method.invoke(target, args); }
            catch (InvocationTargetException exception) { throw exception.getCause(); }
        }

        private void assertClosed() throws SQLException {
            assertThat(connections).isNotEmpty();
            for (var result : results) { assertThat(result.isClosed()).isTrue(); }
            for (var statement : statements) { assertThat(statement.isClosed()).isTrue(); }
            for (var connection : connections) { assertThat(connection.isClosed()).isTrue(); }
        }

        @Override public Connection getConnection(String username, String password) throws SQLException { return getConnection(); }
        @Override public PrintWriter getLogWriter() throws SQLException { return delegate.getLogWriter(); }
        @Override public void setLogWriter(PrintWriter writer) throws SQLException { delegate.setLogWriter(writer); }
        @Override public void setLoginTimeout(int timeout) throws SQLException { delegate.setLoginTimeout(timeout); }
        @Override public int getLoginTimeout() throws SQLException { return delegate.getLoginTimeout(); }
        @Override public Logger getParentLogger() { return Logger.getLogger("com.microflow.common.jdbc.test"); }
        @Override public <T> T unwrap(Class<T> type) throws SQLException { return delegate.unwrap(type); }
        @Override public boolean isWrapperFor(Class<?> type) throws SQLException { return delegate.isWrapperFor(type); }
    }
}
