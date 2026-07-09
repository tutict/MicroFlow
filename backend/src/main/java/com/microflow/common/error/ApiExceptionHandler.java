package com.microflow.common.error;

import jakarta.validation.ConstraintViolationException;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.ext.ExceptionMapper;
import jakarta.ws.rs.ext.Provider;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

final class ApiExceptionPayload {

    private ApiExceptionPayload() {
    }

    static Map<String, Object> body(String error, String message) {
        return Map.of(
                "error", error,
                "message", message == null || message.isBlank() ? error : message
        );
    }
}

@Provider
public class ApiExceptionHandler implements ExceptionMapper<Exception> {

    private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

    @Override
    public Response toResponse(Exception exception) {
        if (exception instanceof IllegalArgumentException) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(ApiExceptionPayload.body("bad_request", exception.getMessage()))
                    .build();
        }
        if (exception instanceof RateLimitExceededException) {
            return Response.status(Response.Status.TOO_MANY_REQUESTS)
                    .entity(ApiExceptionPayload.body("rate_limited", exception.getMessage()))
                    .build();
        }
        if (exception instanceof ConstraintViolationException validationException) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(ApiExceptionPayload.body("validation_error", firstValidationError(validationException)))
                    .build();
        }
        log.error("Unhandled API exception", exception);
        return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .entity(ApiExceptionPayload.body("internal_error", "Internal server error"))
                .build();
    }

    private String firstValidationError(ConstraintViolationException exception) {
        return exception.getConstraintViolations().stream()
                .findFirst()
                .map(violation -> violation.getPropertyPath() + " " + violation.getMessage())
                .orElse("Validation failed");
    }
}
