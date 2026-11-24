package com.microflow.common.jdbc;

public class DuplicateKeyException extends DataIntegrityViolationException {
    public DuplicateKeyException(String message, Throwable cause) { super(message, cause); }
}
