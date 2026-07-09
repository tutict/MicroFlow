package com.microflow.common.error;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.ws.rs.core.Response;
import java.util.Map;
import org.junit.jupiter.api.Test;

class ApiExceptionHandlerTest {

    @Test
    void internalErrorsDoNotExposeExceptionMessages() {
        var response = new ApiExceptionHandler().toResponse(new RuntimeException("jdbc:sqlite:/secret/path.db"));

        assertThat(response.getStatus()).isEqualTo(Response.Status.INTERNAL_SERVER_ERROR.getStatusCode());
        assertThat(response.getEntity()).isInstanceOf(Map.class);
        @SuppressWarnings("unchecked")
        var body = (Map<String, Object>) response.getEntity();
        assertThat(body.get("error")).isEqualTo("internal_error");
        assertThat(body.get("message")).isEqualTo("Internal server error");
        assertThat(body.toString()).doesNotContain("secret/path.db");
    }
}
