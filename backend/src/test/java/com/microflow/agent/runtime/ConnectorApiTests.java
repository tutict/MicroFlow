package com.microflow.agent.runtime;

import static org.assertj.core.api.Assertions.assertThat;

import tools.jackson.databind.ObjectMapper;
import com.microflow.testing.MicroFlowApiTestSupport;
import com.microflow.testing.QuarkusRestTemplate;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.QuarkusTestProfile;
import io.quarkus.test.junit.TestProfile;
import jakarta.inject.Inject;
import java.io.IOException;
import java.net.ServerSocket;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import com.microflow.common.jdbc.JdbcTemplate;

/**
 * Connector settings over HTTP: credential handling, sharing scope, workspace
 * isolation and the connectivity check.
 *
 * <p>The assertions deliberately read the database as well as the API. "The
 * response has no password" is only half the claim; the other half is that the
 * stored column is encrypted.
 */
@QuarkusTest
@TestProfile(ConnectorApiTests.Profile.class)
class ConnectorApiTests extends MicroFlowApiTestSupport {
    @Inject
    private com.microflow.agent.runtime.infrastructure.persistence.JdbcConnectorRepository credentialRepository;

    @org.junit.jupiter.params.ParameterizedTest
    @org.junit.jupiter.params.provider.ValueSource(strings = {"username", "password"})
    void editingOneCredentialPreservesTheOtherWithoutReturningEither(String field) {
        var owner = register(restTemplate, objectMapper, uniqueEmail("patch-secret"), "Owner");
        var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Credential patch");
        var payload = connectorPayload("Mail", "IMAP");
        payload.put("secrets", Map.of("username", "original-user", "password", "original-password"));
        var id = connectorId(post(restTemplate, "/api/v1/workspaces/" + workspaceId + "/connectors", owner, payload));
        var replacement = field.equals("password") ? " replacement password " : "replacement-user";

        var update = exchange(restTemplate, "/api/v1/workspaces/" + workspaceId + "/connectors/" + id,
                HttpMethod.PUT, authJson(owner, Map.of("secrets", Map.of(field, replacement))));

        assertThat(update.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(credentialRepository.findCredentials(id)).isEqualTo(field.equals("password")
                ? Map.of("username", "original-user", "password", " replacement password ")
                : Map.of("username", "replacement-user", "password", "original-password"));
        assertThat(update.getBody()).doesNotContain(replacement, "original-password", "original-user");
    }

    @org.junit.jupiter.params.ParameterizedTest
    @org.junit.jupiter.params.provider.ValueSource(strings = {"update", "delete"})
    void aDemotedViewerCannotManageTheirOwnExistingConnector(String action) {
        var owner = register(restTemplate, objectMapper, uniqueEmail("connector-guard-owner"), "Owner");
        var email = uniqueEmail("connector-viewer");
        var creator = register(restTemplate, objectMapper, email, "Creator");
        var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Existing connector guard");
        addMemberByEmail(restTemplate, owner, workspaceId, email);
        var id = connectorId(post(restTemplate, "/api/v1/workspaces/" + workspaceId + "/connectors", creator,
                connectorPayload("Original connector", "IMAP")));
        changeRole(owner, workspaceId, creator.userId(), "VIEWER");

        var response = exchange(restTemplate, "/api/v1/workspaces/" + workspaceId + "/connectors/" + id,
                action.equals("update") ? HttpMethod.PUT : HttpMethod.DELETE,
                authJson(creator, action.equals("update") ? Map.of("name", "Renamed") : null));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(listFor(creator, workspaceId)).anySatisfy(connector -> {
            assertThat(connector.get("id")).isEqualTo(id);
            assertThat(connector.get("name")).isEqualTo("Original connector");
        });
    }

    @Test
    void aWorkspaceOutsiderCannotUseASharedConnectorForAProbe() throws Exception {
        var owner = register(restTemplate, objectMapper, uniqueEmail("shared-probe-owner"), "Owner");
        var outsider = register(restTemplate, objectMapper, uniqueEmail("shared-probe-outsider"), "Outsider");
        var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Probe isolation");
        var connections = new java.util.concurrent.atomic.AtomicInteger();
        try (var server = new ServerSocket(0, 1, java.net.InetAddress.getByName("127.0.0.1"))) {
            var responder = new Thread(() -> {
                try (var socket = server.accept()) {
                    connections.incrementAndGet();
                    socket.getOutputStream().write("* OK local test mailbox\r\n".getBytes(StandardCharsets.US_ASCII));
                    socket.getOutputStream().flush();
                } catch (IOException ignored) {
                    // A correctly refused request never opens this connection.
                }
            });
            responder.setDaemon(true);
            responder.start();
            var payload = connectorPayload("Workspace mailbox", "IMAP");
            payload.put("config", Map.of("host", "127.0.0.1", "port", server.getLocalPort(), "tls", false));
            payload.put("sharingScope", "WORKSPACE");
            var id = connectorId(post(restTemplate, "/api/v1/workspaces/" + workspaceId + "/connectors", owner, payload));

            var response = post(restTemplate, "/api/v1/workspaces/" + workspaceId + "/connectors/" + id + "/test",
                    outsider, Map.of());

            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
            assertThat(connections).hasValue(0);
            assertThat(credentialRepository.find(id).orElseThrow().lastCheckedAt()).isNull();
        }
    }

    private static final Path databasePath = createDatabasePath();

    private static final String SECRET = "sup3r-secret-app-password";

    public static class Profile implements QuarkusTestProfile {
        @Override
        public Map<String, String> getConfigOverrides() {
            return Map.of(
                    "microflow.database.path", databasePath.toAbsolutePath().toString(),
                    "microflow.seed.demo-enabled", "false",
                    "microflow.jwt.secret", "connector-test-jwt-secret-with-entropy",
                    "microflow.crypto.secret", "ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA="
            );
        }
    }

    private static Path createDatabasePath() {
        try {
            return Files.createTempDirectory("microflow-connector-tests").resolve("connectors.db");
        } catch (IOException exception) {
            throw new IllegalStateException("Unable to create a connector test database path", exception);
        }
    }

    @AfterAll
    static void cleanDatabase() {
        try {
            Files.deleteIfExists(databasePath);
        } catch (IOException ignored) {
            // Windows may still hold the SQLite file handle briefly after shutdown.
        }
    }

    private final QuarkusRestTemplate restTemplate = new QuarkusRestTemplate();

    @Inject
    private ObjectMapper objectMapper;

    @Inject
    private JdbcTemplate jdbcTemplate;

    @Test
    void credentialIsEncryptedAndNeverReturned() {
        var owner = register(restTemplate, objectMapper, uniqueEmail("creator"), "Creator");
        var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Connector Secrets");

        var response = post(
                restTemplate,
                "/api/v1/workspaces/" + workspaceId + "/connectors",
                owner,
                connectorPayload("Mailbox", "IMAP"));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getBody()).doesNotContain(SECRET);

        var body = readMap(objectMapper, response.getBody());
        assertThat(body.get("status")).isEqualTo("UNVERIFIED");
        assertThat(strings(body.get("secretFields")))
                .containsExactly("password", "username");
        assertThat(body.get("sharingScope")).isEqualTo("PRIVATE");
        assertThat(body.get("readEnabled")).isEqualTo(true);
        assertThat(body.get("writeEnabled")).isEqualTo(false);
        assertThat(body.get("ownedByMe")).isEqualTo(true);
        assertThat(body.get("config")).isInstanceOf(Map.class);

        // The stored blob must not be the plaintext, and the column is not TEXT.
        var ciphertext = jdbcTemplate.queryForObject(
                "SELECT secret_ciphertext FROM agent_connectors WHERE id = ?",
                byte[].class,
                body.get("id"));
        assertThat(ciphertext).isNotNull();
        assertThat(new String(ciphertext, StandardCharsets.UTF_8)).doesNotContain(SECRET);

        // Re-reading through the list endpoint stays equally opaque.
        var listed = readList(objectMapper, get(
                restTemplate, "/api/v1/workspaces/" + workspaceId + "/connectors", owner).getBody());
        assertThat(listed).hasSize(1);
        assertThat(strings(listed.getFirst().get("secretFields")))
                .containsExactly("password", "username");
        assertThat(get(
                restTemplate, "/api/v1/workspaces/" + workspaceId + "/connectors", owner).getBody())
                .doesNotContain(SECRET);
    }

    @Test
    void viewersCannotCreateAndOperatorsCannotShareWorkspaceWide() {
        var owner = register(restTemplate, objectMapper, uniqueEmail("conn-owner"), "Owner");
        var viewerEmail = uniqueEmail("conn-viewer");
        var viewer = register(restTemplate, objectMapper, viewerEmail, "Viewer");
        var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Connector Roles");
        addMemberByEmail(restTemplate, owner, workspaceId, viewerEmail);
        changeRole(owner, workspaceId, viewer.userId(), "VIEWER");

        var viewerCreate = post(
                restTemplate,
                "/api/v1/workspaces/" + workspaceId + "/connectors",
                viewer,
                connectorPayload("Nope", "IMAP"));
        assertThat(viewerCreate.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // An operator (the default for a fresh member) may create a private one...
        var operatorEmail = uniqueEmail("conn-operator");
        var operator = register(restTemplate, objectMapper, operatorEmail, "Operator");
        addMemberByEmail(restTemplate, owner, workspaceId, operatorEmail);
        var operatorCreated = post(
                restTemplate,
                "/api/v1/workspaces/" + workspaceId + "/connectors",
                operator,
                connectorPayload("Private notes", "WEBDAV"));
        assertThat(operatorCreated.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        // ...but may not widen it to the whole workspace without a maintainer role.
        var shared = connectorPayload("Private notes", "WEBDAV");
        shared.put("sharingScope", "WORKSPACE");
        var shareAttempt = exchange(
                restTemplate,
                "/api/v1/workspaces/" + workspaceId + "/connectors/" + connectorId(operatorCreated),
                HttpMethod.PUT,
                authJson(operator, shared));
        assertThat(shareAttempt.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void selectedSharingReachesOnlyTheNamedMembers() {
        var owner = register(restTemplate, objectMapper, uniqueEmail("share-owner"), "Sharer");
        var firstEmail = uniqueEmail("share-first");
        var first = register(restTemplate, objectMapper, firstEmail, "First");
        var secondEmail = uniqueEmail("share-second");
        var second = register(restTemplate, objectMapper, secondEmail, "Second");
        var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Connector Sharing");
        addMemberByEmail(restTemplate, owner, workspaceId, firstEmail);
        addMemberByEmail(restTemplate, owner, workspaceId, secondEmail);

        var payload = connectorPayload("Team calendar", "CALDAV");
        payload.put("sharingScope", "SELECTED");
        payload.put("sharedUserIds", List.of(first.userId()));
        var created = post(
                restTemplate, "/api/v1/workspaces/" + workspaceId + "/connectors", owner, payload);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        var connectorId = connectorId(created);

        assertThat(listFor(first, workspaceId)).hasSize(1);
        assertThat(listFor(second, workspaceId)).isEmpty();

        var secondRead = post(
                restTemplate,
                "/api/v1/workspaces/" + workspaceId + "/connectors/" + connectorId + "/test",
                second,
                Map.of());
        assertThat(secondRead.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        // Deleting someone else's connector is refused even for a shared one.
        var firstDelete = exchange(
                restTemplate,
                "/api/v1/workspaces/" + workspaceId + "/connectors/" + connectorId,
                HttpMethod.DELETE,
                authJson(first, null));
        assertThat(firstDelete.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void connectorsAreIsolatedPerWorkspace() {
        var owner = register(restTemplate, objectMapper, uniqueEmail("iso-owner"), "Owner");
        var firstWorkspace = createWorkspace(restTemplate, objectMapper, owner, "Connector A");
        var secondWorkspace = createWorkspace(restTemplate, objectMapper, owner, "Connector B");

        var created = post(
                restTemplate,
                "/api/v1/workspaces/" + firstWorkspace + "/connectors",
                owner,
                connectorPayload("Only here", "IMAP"));
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        var connectorId = connectorId(created);

        assertThat(listFor(owner, secondWorkspace)).isEmpty();
        var crossWorkspaceTest = post(
                restTemplate,
                "/api/v1/workspaces/" + secondWorkspace + "/connectors/" + connectorId + "/test",
                owner,
                Map.of());
        assertThat(crossWorkspaceTest.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void connectivityCheckRecordsTheOutcome() throws Exception {
        var owner = register(restTemplate, objectMapper, uniqueEmail("probe"), "Prober");
        var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Connector Probe");

        try (var server = new ServerSocket(0)) {
            var responder = new Thread(() -> {
                try (var socket = server.accept()) {
                    socket.getOutputStream().write(
                            "* OK fake IMAP ready\r\n".getBytes(StandardCharsets.US_ASCII));
                    socket.getOutputStream().flush();
                    Thread.sleep(300);
                } catch (Exception ignored) {
                    // The probe closing early is the expected path.
                }
            });
            responder.setDaemon(true);
            responder.start();

            var payload = connectorPayload("Reachable mailbox", "IMAP");
            @SuppressWarnings("unchecked")
            var config = (Map<String, Object>) payload.get("config");
            config.put("host", "127.0.0.1");
            config.put("port", server.getLocalPort());
            config.put("tls", false);

            var created = post(
                    restTemplate, "/api/v1/workspaces/" + workspaceId + "/connectors", owner, payload);
            var connectorId = connectorId(created);

            var check = post(
                    restTemplate,
                    "/api/v1/workspaces/" + workspaceId + "/connectors/" + connectorId + "/test",
                    owner,
                    Map.of());
            assertThat(check.getStatusCode()).isEqualTo(HttpStatus.OK);
            var body = readMap(objectMapper, check.getBody());
            assertThat(body.get("status")).isEqualTo("ACTIVE");
            assertThat(body.get("detail")).asString().contains("IMAP greeting");
            assertThat(body.get("checkedAt")).isNotNull();

            var listed = readList(objectMapper, get(
                    restTemplate, "/api/v1/workspaces/" + workspaceId + "/connectors", owner).getBody());
            assertThat(listed.getFirst().get("status")).isEqualTo("ACTIVE");
        }

        var unreachable = connectorPayload("Closed port", "IMAP");
        @SuppressWarnings("unchecked")
        var unreachableConfig = (Map<String, Object>) unreachable.get("config");
        unreachableConfig.put("host", "127.0.0.1");
        unreachableConfig.put("port", 1);
        unreachableConfig.put("tls", false);
        var createdUnreachable = post(
                restTemplate, "/api/v1/workspaces/" + workspaceId + "/connectors", owner, unreachable);
        var failed = post(
                restTemplate,
                "/api/v1/workspaces/" + workspaceId + "/connectors/"
                        + connectorId(createdUnreachable) + "/test",
                owner,
                Map.of());
        assertThat(failed.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(readMap(objectMapper, failed.getBody()).get("status")).isEqualTo("FAILED");
    }

    @Test
    void updateWithoutCredentialsKeepsTheStoredSecret() {
        var owner = register(restTemplate, objectMapper, uniqueEmail("keep"), "Keeper");
        var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Connector Keep");
        var created = post(
                restTemplate,
                "/api/v1/workspaces/" + workspaceId + "/connectors",
                owner,
                connectorPayload("Mailbox", "IMAP"));
        var connectorId = connectorId(created);

        var rename = new LinkedHashMap<String, Object>();
        rename.put("name", "Renamed mailbox");
        var updated = exchange(
                restTemplate,
                "/api/v1/workspaces/" + workspaceId + "/connectors/" + connectorId,
                HttpMethod.PUT,
                authJson(owner, rename));
        assertThat(updated.getStatusCode()).isEqualTo(HttpStatus.OK);
        var body = readMap(objectMapper, updated.getBody());
        assertThat(body.get("name")).isEqualTo("Renamed mailbox");
        assertThat(strings(body.get("secretFields")))
                .containsExactly("password", "username");
        assertThat(updated.getBody()).doesNotContain(SECRET);
    }

    @Test
    void plainHttpIsRejectedForRemoteHosts() {
        var owner = register(restTemplate, objectMapper, uniqueEmail("insecure"), "Insecure");
        var workspaceId = createWorkspace(restTemplate, objectMapper, owner, "Connector TLS");
        var payload = connectorPayload("Remote drive", "WEBDAV");
        @SuppressWarnings("unchecked")
        var config = (Map<String, Object>) payload.get("config");
        config.put("baseUrl", "http://files.example.com/dav");

        var response = post(
                restTemplate, "/api/v1/workspaces/" + workspaceId + "/connectors", owner, payload);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    // ------------------------------------------------------------------ helpers

    private List<String> strings(Object value) {
        return ((List<?>) value).stream().map(String::valueOf).toList();
    }

    private String uniqueEmail(String prefix) {
        return prefix + "-" + System.nanoTime() + "@example.com";
    }

    private Map<String, Object> connectorPayload(String name, String kind) {
        var config = new LinkedHashMap<String, Object>();
        if ("IMAP".equals(kind) || "SMTP".equals(kind)) {
            config.put("host", "imap.example.com");
            config.put("port", 993);
            config.put("tls", true);
        } else {
            config.put("baseUrl", "https://dav.example.com/calendars/team");
        }
        var payload = new LinkedHashMap<String, Object>();
        payload.put("kind", kind);
        payload.put("name", name);
        payload.put("config", config);
        payload.put("secrets", Map.of("username", "user@example.com", "password", SECRET));
        payload.put("sharingScope", "PRIVATE");
        return payload;
    }

    private String connectorId(org.springframework.http.ResponseEntity<String> response) {
        return String.valueOf(readMap(objectMapper, response.getBody()).get("id"));
    }

    private List<Map<String, Object>> listFor(Session session, String workspaceId) {
        return readList(objectMapper, get(
                restTemplate, "/api/v1/workspaces/" + workspaceId + "/connectors", session).getBody());
    }

    private void changeRole(Session owner, String workspaceId, String userId, String role) {
        var response = exchange(
                restTemplate,
                "/api/v1/workspaces/" + workspaceId + "/members/" + userId + "/role",
                HttpMethod.PUT,
                authJson(owner, Map.of("role", role)));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }
}
