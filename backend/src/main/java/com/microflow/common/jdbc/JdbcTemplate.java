package com.microflow.common.jdbc;

import java.math.BigDecimal;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import javax.sql.DataSource;
import org.sqlite.SQLiteErrorCode;
import org.sqlite.SQLiteException;

/**
 * The JDBC operations used by MicroFlow, with one owned connection per operation.
 * Connection auto-commit and transaction settings are left to the existing data source.
 */
public class JdbcTemplate {
    private final DataSource dataSource;

    public JdbcTemplate(DataSource dataSource) {
        this.dataSource = Objects.requireNonNull(dataSource, "dataSource");
    }

    public <T> List<T> query(String sql, RowMapper<T> mapper, Object... parameters) {
        var rows = new ArrayList<T>();
        query(sql, resultSet -> { rows.add(mapper.mapRow(resultSet, rows.size())); }, parameters);
        return rows;
    }

    public void query(String sql, RowCallbackHandler callback, Object... parameters) {
        try (var connection = dataSource.getConnection();
             var statement = connection.prepareStatement(sql)) {
            bind(statement, parameters);
            try (var rows = statement.executeQuery()) {
                while (rows.next()) {
                    callback.processRow(rows);
                }
            }
        } catch (SQLException exception) {
            throw translate(exception);
        }
    }

    public <T> T query(String sql, ResultSetExtractor<T> extractor, Object... parameters) {
        try (var connection = dataSource.getConnection();
             var statement = connection.prepareStatement(sql)) {
            bind(statement, parameters);
            try (var rows = statement.executeQuery()) {
                return extractor.extractData(rows);
            }
        } catch (SQLException exception) {
            throw translate(exception);
        }
    }

    public <T> T queryForObject(String sql, RowMapper<T> mapper, Object... parameters) {
        var rows = query(sql, mapper, parameters);
        if (rows.isEmpty()) {
            throw new EmptyResultDataAccessException(1);
        }
        if (rows.size() != 1) {
            throw new IncorrectResultSizeDataAccessException(1, rows.size());
        }
        return rows.getFirst();
    }

    public <T> T queryForObject(String sql, Class<T> requiredType, Object... parameters) {
        return queryForObject(sql, (rows, rowNumber) -> scalar(rows, requiredType), parameters);
    }

    public <T> List<T> queryForList(String sql, Class<T> requiredType, Object... parameters) {
        return query(sql, (rows, rowNumber) -> scalar(rows, requiredType), parameters);
    }

    public List<Map<String, Object>> queryForList(String sql, Object... parameters) {
        return query(sql, (rows, rowNumber) -> {
            var metadata = rows.getMetaData();
            Map<String, Object> values = new ColumnMap();
            for (int column = 1; column <= metadata.getColumnCount(); column++) {
                var label = metadata.getColumnLabel(column);
                if (!values.containsKey(label)) {
                    values.put(label, rows.getObject(column));
                }
            }
            return values;
        }, parameters);
    }

    public int update(String sql, Object... parameters) {
        try (var connection = dataSource.getConnection();
             var statement = connection.prepareStatement(sql)) {
            bind(statement, parameters);
            return statement.executeUpdate();
        } catch (SQLException exception) {
            throw translate(exception);
        }
    }

    public int update(PreparedStatementCreator creator) {
        try (var connection = dataSource.getConnection();
             var statement = creator.createPreparedStatement(connection)) {
            return statement.executeUpdate();
        } catch (SQLException exception) {
            throw translate(exception);
        }
    }

    public void execute(String sql) {
        try (var connection = dataSource.getConnection();
             var statement = connection.createStatement()) {
            statement.execute(sql);
        } catch (SQLException exception) {
            throw translate(exception);
        }
    }

    public <T> int[][] batchUpdate(String sql, Collection<T> values, int batchSize,
                                  ParameterizedPreparedStatementSetter<T> setter) {
        if (!values.isEmpty() && batchSize <= 0) {
            throw new IllegalArgumentException("batchSize must be positive for non-empty input");
        }
        try (var connection = dataSource.getConnection();
             var statement = connection.prepareStatement(sql)) {
            var counts = new ArrayList<int[]>();
            var supportsBatch = connection.getMetaData().supportsBatchUpdates();
            int pending = 0;
            for (var value : values) {
                setter.setValues(statement, value);
                if (supportsBatch) {
                    statement.addBatch();
                    if (++pending == batchSize) {
                        counts.add(statement.executeBatch());
                        statement.clearBatch();
                        pending = 0;
                    }
                } else {
                    counts.add(new int[] {statement.executeUpdate()});
                }
            }
            if (pending > 0) {
                counts.add(statement.executeBatch());
            }
            return counts.toArray(int[][]::new);
        } catch (SQLException exception) {
            throw translate(exception);
        }
    }

    private static void bind(PreparedStatement statement, Object[] parameters) throws SQLException {
        if (parameters == null) {
            return;
        }
        for (int offset = 0; offset < parameters.length; offset++) {
            var parameter = parameters[offset];
            int index = offset + 1;
            if (parameter == null) {
                statement.setNull(index, Types.NULL);
            } else if (parameter instanceof byte[] bytes) {
                statement.setBytes(index, bytes);
            } else if (parameter instanceof String text) {
                statement.setString(index, text);
            } else if (parameter instanceof BigDecimal decimal) {
                statement.setBigDecimal(index, decimal);
            } else {
                statement.setObject(index, parameter);
            }
        }
    }

    @SuppressWarnings("unchecked")
    private static <T> T scalar(ResultSet rows, Class<T> requiredType) throws SQLException {
        if (rows.getMetaData().getColumnCount() != 1) {
            throw new DataAccessException("Scalar query requires exactly one column");
        }
        Object value;
        if (requiredType == String.class) {
            value = rows.getString(1);
        } else if (requiredType == Integer.class || requiredType == int.class) {
            value = rows.getInt(1);
        } else if (requiredType == Long.class || requiredType == long.class) {
            value = rows.getLong(1);
        } else if (requiredType == byte[].class) {
            value = rows.getBytes(1);
        } else if (requiredType == BigDecimal.class) {
            value = rows.getBigDecimal(1);
        } else if (requiredType == Object.class) {
            value = rows.getObject(1);
        } else {
            throw new DataAccessException("Unsupported scalar type: " + requiredType.getName());
        }
        return value == null || rows.wasNull() ? null : (T) value;
    }

    private static DataAccessException translate(SQLException exception) {
        // SQLite stores extended constraint codes on the driver exception, including batch causes.
        for (Throwable cause = exception; cause != null; cause = cause.getCause()) {
            if (cause instanceof SQLiteException sqlite) {
                var code = sqlite.getResultCode();
                if (code == SQLiteErrorCode.SQLITE_CONSTRAINT_UNIQUE
                        || code == SQLiteErrorCode.SQLITE_CONSTRAINT_PRIMARYKEY
                        || code == SQLiteErrorCode.SQLITE_CONSTRAINT_ROWID) {
                    return new DuplicateKeyException("JDBC unique constraint violation", exception);
                }
                if ((code.code & 0xff) == SQLiteErrorCode.SQLITE_CONSTRAINT.code) {
                    return new DataIntegrityViolationException("JDBC integrity constraint violation", exception);
                }
            }
        }
        return new DataAccessException("JDBC operation failed", exception);
    }

    /** Column labels keep their original order and spelling, with case-insensitive lookup. */
    private static final class ColumnMap extends LinkedHashMap<String, Object> {
        @Override
        public Object get(Object key) {
            return super.get(storedKey(key));
        }

        @Override
        public boolean containsKey(Object key) {
            return super.containsKey(storedKey(key));
        }

        private Object storedKey(Object key) {
            if (key instanceof String text) {
                for (var label : keySet()) {
                    if (label.equalsIgnoreCase(text)) {
                        return label;
                    }
                }
            }
            return key;
        }
    }
}
