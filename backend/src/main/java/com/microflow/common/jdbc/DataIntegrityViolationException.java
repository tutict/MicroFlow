package com.microflow.common.jdbc;

public class DataIntegrityViolationException extends DataAccessException {
    public DataIntegrityViolationException(String message, Throwable cause) { super(message, cause); }
}
