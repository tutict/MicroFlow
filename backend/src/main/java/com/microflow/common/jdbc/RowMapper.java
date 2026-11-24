package com.microflow.common.jdbc;

import java.sql.ResultSet;
import java.sql.SQLException;

@FunctionalInterface
public interface RowMapper<T> {
    T mapRow(ResultSet resultSet, int rowNumber) throws SQLException;
}
