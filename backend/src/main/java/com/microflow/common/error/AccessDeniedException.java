package com.microflow.common.error;

/**
 * Raised when an authenticated caller lacks the membership or ownership required
 * for the requested resource. Mapped to HTTP 403 so authorization failures are
 * never reported as internal errors.
 */
public class AccessDeniedException extends RuntimeException {

    public AccessDeniedException(String message) {
        super(message);
    }
}
