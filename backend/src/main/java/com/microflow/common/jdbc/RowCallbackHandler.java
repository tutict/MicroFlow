package com.microflow.common.jdbc;

import java.sql.ResultSet;
import java.sql.SQLException;

@FunctionalInterface
public interface RowCallbackHandler {
    void processRow(ResultSet resultSet) throws SQLException;
}
