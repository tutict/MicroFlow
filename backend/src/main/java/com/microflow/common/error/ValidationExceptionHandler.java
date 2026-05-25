package com.microflow.common.error;

import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.ext.ExceptionMapper;
import jakarta.ws.rs.ext.Provider;
import org.jboss.resteasy.api.validation.ResteasyViolationException;

@Provider
public class ValidationExceptionHandler implements ExceptionMapper<ResteasyViolationException> {

    @Override
    public Response toResponse(ResteasyViolationException exception) {
        var firstError = exception.getViolations().stream()
                .findFirst()
                .map(violation -> violation.getPath() + " " + violation.getMessage())
                .orElse("Validation failed");
        return Response.status(Response.Status.BAD_REQUEST)
                .entity(ApiExceptionPayload.body("validation_error", firstError))
                .build();
    }
}
