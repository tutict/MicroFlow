package com.microflow.common.jdbc;

public class IncorrectResultSizeDataAccessException extends DataAccessException {
    private final int expectedSize;
    private final int actualSize;

    public IncorrectResultSizeDataAccessException(int expectedSize, int actualSize) {
        super("Expected " + expectedSize + " row(s), found " + actualSize);
        this.expectedSize = expectedSize;
        this.actualSize = actualSize;
    }

    public int getExpectedSize() { return expectedSize; }
    public int getActualSize() { return actualSize; }
}
