package com.microflow.common.error;

/**
 * Raised when a write loses a race against another writer and therefore changed
 * nothing. Mapped to HTTP 409 so callers can retry instead of treating the
 * attempt as either a silent success or a server fault.
 */
public class ConcurrentModificationException extends RuntimeException {

    public ConcurrentModificationException(String message) {
        super(message);
    }
}
