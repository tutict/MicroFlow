package com.microflow.common.jdbc;

public class EmptyResultDataAccessException extends IncorrectResultSizeDataAccessException {
    public EmptyResultDataAccessException(int expectedSize) { super(expectedSize, 0); }
}
