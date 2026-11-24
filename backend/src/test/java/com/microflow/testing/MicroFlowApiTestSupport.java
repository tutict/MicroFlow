package com.microflow.testing;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

/**
 * Shared plumbing for the API integration tests: a registered session, JSON
 * request/response helpers and payload parsing.
 *
 * <p>These helpers were previously copied verbatim into every test class, which
 * meant a change to how requests are authenticated had to be repeated in four
 * places. A wrong fix in one copy would leave the suite quietly inconsistent.
 */
public abstract class MicroFlowApiTestSupport {

    /** An access token plus the user id it belongs to. */
    public record Session(String token, String userId) {
    }

    /**
     * Builds a JSON request, attaching a bearer token when the session carries one.
     * A null session is used for unauthenticated calls such as register.
     */
    protected HttpEntity<?> authJson(Session session, Map<String, Object> body) {
        var headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        if (session != null && session.token() != null && !session.token().isEmpty()) {
            headers.setBearerAuth(session.token());
        }
        return new HttpEntity<>(body, headers);
    }

    protected ResponseEntity<String> exchange(
            QuarkusRestTemplate restTemplate,
            String path,
            HttpMethod method,
            HttpEntity<?> entity
    ) {
        return restTemplate.exchange(path, method, entity, String.class);
    }

    protected ResponseEntity<String> post(
            QuarkusRestTemplate restTemplate, String path, Session session, Map<String, Object> body
    ) {
        return exchange(restTemplate, path, HttpMethod.POST, authJson(session, body));
    }

    protected ResponseEntity<String> get(
            QuarkusRestTemplate restTemplate, String path, Session session
    ) {
        return exchange(restTemplate, path, HttpMethod.GET, authJson(session, null));
    }

    protected Session register(
            QuarkusRestTemplate restTemplate,
            ObjectMapper objectMapper,
            String email,
            String displayName
    ) {
        var response = post(restTemplate, "/api/v1/auth/register", null, Map.of(
                "email", email,
                "password", TEST_PASSWORD,
                "displayName", displayName));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        var payload = readMap(objectMapper, response.getBody());
        return new Session(
                String.valueOf(payload.get("accessToken")),
                String.valueOf(payload.get("userId")));
    }

    protected String createWorkspace(
            QuarkusRestTemplate restTemplate,
            ObjectMapper objectMapper,
            Session session,
            String name
    ) {
        var response = post(restTemplate, "/api/v1/workspaces", session, Map.of("name", name));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return String.valueOf(readMap(objectMapper, response.getBody()).get("id"));
    }

    protected void addMemberByEmail(
            QuarkusRestTemplate restTemplate,
            Session owner,
            String workspaceId,
            String email
    ) {
        var response = post(
                restTemplate,
                "/api/v1/workspaces/" + workspaceId + "/members",
                owner,
                Map.of("email", email));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    protected String createTaskId(
            QuarkusRestTemplate restTemplate,
            ObjectMapper objectMapper,
            Session actor,
            String workspaceId,
            Map<String, Object> body
    ) {
        var payload = new java.util.LinkedHashMap<String, Object>();
        payload.put("title", "Test task");
        payload.putAll(body);
        var response = post(
                restTemplate, "/api/v1/workspaces/" + workspaceId + "/tasks", actor, payload);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return String.valueOf(readMap(objectMapper, response.getBody()).get("id"));
    }

    protected Map<String, Object> readMap(ObjectMapper objectMapper, String body) {
        try {
            return objectMapper.readValue(body, new TypeReference<Map<String, Object>>() {
            });
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to parse response: " + body, exception);
        }
    }

    protected List<Map<String, Object>> readList(ObjectMapper objectMapper, String body) {
        try {
            return objectMapper.readValue(body, new TypeReference<List<Map<String, Object>>>() {
            });
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to parse list response: " + body, exception);
        }
    }

    protected static final String TEST_PASSWORD = "Passw0rd!2345";
}
