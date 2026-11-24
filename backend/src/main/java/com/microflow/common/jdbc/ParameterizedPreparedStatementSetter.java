package com.microflow.common.jdbc;

import java.sql.PreparedStatement;
import java.sql.SQLException;

@FunctionalInterface
public interface ParameterizedPreparedStatementSetter<T> {
    void setValues(PreparedStatement statement, T value) throws SQLException;
}
