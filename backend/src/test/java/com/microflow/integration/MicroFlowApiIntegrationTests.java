package com.microflow.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.fail;

import com.microflow.bootstrap.MicroFlowApplication;
import com.microflow.bootstrap.pairing.PairingService;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.WebSocket;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionStage;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.function.Predicate;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

@SpringBootTest(
        classes = MicroFlowApplication.class,
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT
)
class MicroFlowApiIntegrationTests {

    private static final Path databasePath = createDatabasePath();

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", () -> "jdbc:sqlite:" + databasePath.toAbsolutePath());
        registry.add("microflow.agent.mock-delay", () -> "PT0.05S");
        registry.add("microflow.agent.openclaw-state-dir", () -> databasePath.resolveSibling("missing-qclaw-state").toString());
        registry.add("microflow.seed.demo-enabled", () -> "true");
        registry.add("microflow.jwt.secret", () -> "integration-test-jwt-secret-with-entropy");
        registry.add("microflow.crypto.secret", () -> "ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA=");
    }

    @AfterAll
    static void cleanDatabase() {
        try {
            Files.deleteIfExists(databasePath);
        } catch (IOException ignored) {
            // Windows may still hold the SQLite file handle briefly after shutdown.
        }
    }

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private PairingService pairingService;

    @LocalServerPort
    private int port;

    @Test
    void protectedWorkspaceEndpointRejectsMissingBearerToken() {
        var response = restTemplate.getForEntity("/api/v1/workspaces", String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(response.getBody()).contains("\"status\":401");
        assertThat(response.getBody()).contains("\"error\":\"Unauthorized\"");
    }

    @Test
    void bootstrapPairingReturnsRuntimeUrlsAndConsumesTheCode() throws Exception {
        var challenge = pairingService.currentChallenge();

        var response = restTemplate.postForEntity(
                "/api/v1/bootstrap/pair",
                Map.of("pairingCode", challenge.code()),
                String.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        var payload = readJsonObject(response);
        assertThat(payload.get("instanceName")).isEqualTo("microflow");
        assertThat(payload.get("apiBaseUrl")).isEqualTo("http://localhost:" + port + "/api/v1");
        assertThat(payload.get("wsBaseUrl")).isEqualTo("ws://localhost:" + port + "/ws");

        var secondResponse = restTemplate.postForEntity(
                "/api/v1/bootstrap/pair",
                Map.of("pairingCode", challenge.code()),
                String.class
        );
        assertThat(secondResponse.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(secondResponse.getBody()).contains("Invalid pairing code");
    }

    @Test
    void localPairingConsoleEndpointsExposeChallengeAndQrCode() throws Exception {
        var challenge = restTemplate.getForEntity("/api/v1/bootstrap/challenge", String.class);
        assertThat(challenge.getStatusCode()).isEqualTo(HttpStatus.OK);
        var payload = readJsonObject(challenge);
        assertThat(payload.get("pairingCode")).isNotNull();
        assertThat(payload.get("apiBaseUrl")).isEqualTo("http://localhost:" + port + "/api/v1");
        assertThat(payload.get("qrPayload")).isInstanceOf(String.class);

        var qr = restTemplate.getForEntity("/api/v1/bootstrap/qr", byte[].class);
        assertThat(qr.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(qr.getHeaders().getContentType()).isEqualTo(MediaType.IMAGE_PNG);
        assertThat(qr.getBody()).isNotNull();
        assertThat(qr.getBody()).startsWith(
                (byte) 0x89, (byte) 0x50, (byte) 0x4E, (byte) 0x47
        );

        var console = restTemplate.getForEntity("/api/v1/bootstrap/console", String.class);
        assertThat(console.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(console.getBody()).contains("MicroFlow Pairing Console");
        assertThat(console.getBody()).contains("/api/v1/bootstrap/qr");
    }

    @Test
    void localPairingConsoleRejectsForwardedExternalRequests() {
        var headers = new HttpHeaders();
        headers.add("X-Forwarded-For", "198.51.100.24");
        headers.add(HttpHeaders.HOST, "localhost:" + port);

        var response = restTemplate.exchange(
                "/api/v1/bootstrap/challenge",
                HttpMethod.GET,
                new HttpEntity<>(headers),
                String.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).contains("Pairing console is only available from the local machine");
    }

    @Test
    void bootstrapPairingRejectsUnconfiguredNonLocalHost() {
        var challenge = pairingService.currentChallenge();
        var headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.add("X-Forwarded-Host", "attacker.example");

        var response = restTemplate.exchange(
                "/api/v1/bootstrap/pair",
                HttpMethod.POST,
                new HttpEntity<>(Map.of("pairingCode", challenge.code()), headers),
                String.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).contains("Non-local pairing origin must be configured");
    }

    @Test
    void agentDiagnosticsExposeConfiguredProviderAndConnectivityStatus() throws Exception {
        var session = loginDemoUser();
        var workspace = firstWorkspace(session.accessToken());

        var response = restTemplate.exchange(
                "/api/v1/agent-diagnostics?workspaceId=" + workspace.id(),
                HttpMethod.GET,
                authenticatedEntity(session.accessToken()),
                String.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        var diagnostics = readJsonList(response);
        assertThat(diagnostics).isNotEmpty();
        assertThat(diagnostics).anySatisfy(diagnostic -> {
            assertThat(diagnostic.get("agentKey")).isEqualTo("assistant");
            assertThat(diagnostic.get("provider")).isEqualTo("mock-openclaw");
            assertThat(diagnostic.get("status")).isEqualTo("SIMULATED");
        });
    }

    @Test
    void roleStrategyCanBeUpdatedAndIsReflectedInDiagnosticsAndCollaboration() throws Exception {
        var session = loginDemoUser();
        var workspace = firstWorkspace(session.accessToken());
        var channel = channelByName(session.accessToken(), workspace.id(), "general");
        var customStrategy = "You are the release captain. Focus on launch sequencing, dependencies, and readiness gates.";

        try {
            var updateResponse = restTemplate.exchange(
                    "/api/v1/agents/assistant/role-strategy?workspaceId=" + workspace.id(),
                    HttpMethod.PUT,
                    authenticatedJsonEntity(session.accessToken(), Map.of("roleStrategy", customStrategy)),
                    String.class
            );
            assertThat(updateResponse.getStatusCode()).isEqualTo(HttpStatus.OK);

            var diagnosticsResponse = restTemplate.exchange(
                    "/api/v1/agent-diagnostics?workspaceId=" + workspace.id(),
                    HttpMethod.GET,
                    authenticatedEntity(session.accessToken()),
                    String.class
            );
            assertThat(diagnosticsResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
            var diagnostics = readJsonList(diagnosticsResponse);
            assertThat(diagnostics).anySatisfy(diagnostic -> {
                assertThat(diagnostic.get("agentKey")).isEqualTo("assistant");
                assertThat(diagnostic.get("roleStrategy")).isEqualTo(customStrategy);
            });

            var listener = new QueueingWebSocketListener();
            WebSocket socket = null;
            try {
                socket = HttpClient.newHttpClient()
                        .newWebSocketBuilder()
                        .connectTimeout(Duration.ofSeconds(5))
                        .buildAsync(
                                URI.create("ws://localhost:" + port + "/ws?ticket=" + issueWebSocketTicket(session.accessToken())),
                                listener
                        )
                        .join();

                socket.sendText(
                        objectMapper.writeValueAsString(Map.of(
                                "type", "SUBSCRIBE",
                                "payload", Map.of("channelId", channel.id())
                        )),
                        true
                ).join();

                assertThat(awaitMessages(listener.messages(), 1))
                        .singleElement()
                        .satisfies(message -> assertThat(message).contains("\"type\":\"SUBSCRIBED\""));

                socket.sendText(
                        objectMapper.writeValueAsString(Map.of(
                                "type", "CHAT_SEND",
                                "channelId", channel.id(),
                                "payload", Map.of(
                                        "workspaceId", workspace.id(),
                                        "content", "@team prepare release checklist " + System.nanoTime()
                                )
                        )),
                        true
                ).join();

                var events = awaitMessagesUntil(
                        listener.messages(),
                        40,
                        collected -> containsEventType(collected, "COLLABORATION_COMPLETED")
                                && containsAgentMessage(collected, "assistant", customStrategy)
                );
                assertThat(events).anySatisfy(message -> assertThat(message).contains(customStrategy));
            } finally {
                if (socket != null) {
                    socket.sendClose(WebSocket.NORMAL_CLOSURE, "done").join();
                }
            }
        } finally {
            restTemplate.exchange(
                    "/api/v1/agents/assistant/role-strategy?workspaceId=" + workspace.id(),
                    HttpMethod.PUT,
                    authenticatedJsonEntity(session.accessToken(), Map.of("roleStrategy", "")),
                    String.class
            );
        }
    }

    @Test
    void roleStrategyRejectsOversizedInput() throws Exception {
        var session = loginDemoUser();
        var workspace = firstWorkspace(session.accessToken());
        var oversizedStrategy = "x".repeat(1001);

        var response = restTemplate.exchange(
                "/api/v1/agents/assistant/role-strategy?workspaceId=" + workspace.id(),
                HttpMethod.PUT,
                authenticatedJsonEntity(session.accessToken(), Map.of("roleStrategy", oversizedStrategy)),
                String.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).contains("Role strategy must be 1000 characters or fewer");
    }

    @Test
    void loginAllowsProfileLookupForDemoUser() throws Exception {
        var session = loginDemoUser();

        var response = restTemplate.exchange(
                "/api/v1/auth/me",
                HttpMethod.GET,
                authenticatedEntity(session.accessToken()),
                String.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        var profile = readJsonObject(response).get("displayName");
        assertThat(profile).isEqualTo("Demo Builder");
    }

    @Test
    void loginRateLimitReturnsTooManyRequestsAfterRepeatedFailures() throws Exception {
        var email = "ratelimit-" + System.nanoTime() + "@microflow.local";
        var session = registerUser(email);
        assertThat(session.accessToken()).isNotBlank();

        ResponseEntity<String> response = null;
        for (var attempt = 0; attempt < 6; attempt++) {
            response = restTemplate.postForEntity(
                    "/api/v1/auth/login",
                    Map.of("email", email, "password", "wrong-password"),
                    String.class
            );
        }

        assertThat(response).isNotNull();
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        assertThat(response.getBody()).contains("Too many login attempts");
    }

    @Test
    void restMessageFlowPersistsAndReturnsMessages() throws Exception {
        var session = loginDemoUser();
        var workspace = firstWorkspace(session.accessToken());
        var channel = firstChannel(session.accessToken(), workspace.id());
        var content = "rest integration message " + System.nanoTime();

        var sendResponse = restTemplate.exchange(
                "/api/v1/channels/" + channel.id() + "/messages",
                HttpMethod.POST,
                authenticatedJsonEntity(
                        session.accessToken(),
                        Map.of("workspaceId", workspace.id(), "content", content)
                ),
                String.class
        );

        assertThat(sendResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(readJsonObject(sendResponse).get("content")).isEqualTo(content);

        var listResponse = restTemplate.exchange(
                "/api/v1/channels/" + channel.id() + "/messages",
                HttpMethod.GET,
                authenticatedEntity(session.accessToken()),
                String.class
        );

        assertThat(listResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        var messages = readJsonList(listResponse);
        assertThat(messages).anySatisfy(message -> {
            assertThat(message.get("channelId")).isEqualTo(channel.id());
            assertThat(message.get("content")).isEqualTo(content);
        });
    }

    @Test
    void restMessageFlowRejectsOversizedMessages() throws Exception {
        var session = loginDemoUser();
        var workspace = firstWorkspace(session.accessToken());
        var channel = firstChannel(session.accessToken(), workspace.id());
        var oversized = "x".repeat(4001);

        var response = restTemplate.exchange(
                "/api/v1/channels/" + channel.id() + "/messages",
                HttpMethod.POST,
                authenticatedJsonEntity(
                        session.accessToken(),
                        Map.of("workspaceId", workspace.id(), "content", oversized)
                ),
                String.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).contains("validation_error");
    }

    @Test
    void websocketSendFlowAcknowledgesAndBroadcastsMessages() throws Exception {
        var session = loginDemoUser();
        var workspace = firstWorkspace(session.accessToken());
        var channel = firstChannel(session.accessToken(), workspace.id());
        var listener = new QueueingWebSocketListener();
        WebSocket socket = null;
        try {
            socket = HttpClient.newHttpClient()
                    .newWebSocketBuilder()
                    .connectTimeout(Duration.ofSeconds(5))
                    .buildAsync(
                            URI.create("ws://localhost:" + port + "/ws?ticket=" + issueWebSocketTicket(session.accessToken())),
                            listener
                    )
                    .join();

            socket.sendText(
                    objectMapper.writeValueAsString(Map.of(
                            "type", "SUBSCRIBE",
                            "payload", Map.of("channelId", channel.id())
                    )),
                    true
            ).join();

            assertThat(awaitMessages(listener.messages(), 1))
                    .singleElement()
                    .satisfies(message -> assertThat(message).contains("\"type\":\"SUBSCRIBED\""));

            var content = "websocket integration message " + System.nanoTime();
            socket.sendText(
                    objectMapper.writeValueAsString(Map.of(
                            "type", "CHAT_SEND",
                            "channelId", channel.id(),
                            "payload", Map.of("workspaceId", workspace.id(), "content", content)
                    )),
                    true
            ).join();

            var events = awaitMessages(listener.messages(), 2);
            assertThat(events).anySatisfy(message -> assertThat(message).contains("\"type\":\"ACK\""));

            var messageCreatedEvent = events.stream()
                    .filter(message -> message.contains("\"type\":\"MESSAGE_CREATED\""))
                    .findFirst()
                    .orElseThrow(() -> new AssertionError("Expected MESSAGE_CREATED event"));
            var payload = readJsonObject(messageCreatedEvent).get("payload");
            assertThat(payload).isInstanceOf(Map.class);
            @SuppressWarnings("unchecked")
            var payloadMap = (Map<String, Object>) payload;
            assertThat(payloadMap.get("channelId")).isEqualTo(channel.id());
            assertThat(payloadMap.get("workspaceId")).isEqualTo(workspace.id());
            assertThat(payloadMap.get("content")).isEqualTo(content);
        } finally {
            if (socket != null) {
                socket.sendClose(WebSocket.NORMAL_CLOSURE, "done").join();
            }
        }
    }

    @Test
    void agentMentionFlowPublishesRunLifecycleAndAgentReply() throws Exception {
        var session = loginDemoUser();
        var workspace = firstWorkspace(session.accessToken());
        var channel = channelByName(session.accessToken(), workspace.id(), "general");
        var listener = new QueueingWebSocketListener();
        WebSocket socket = null;
        try {
            socket = HttpClient.newHttpClient()
                    .newWebSocketBuilder()
                    .connectTimeout(Duration.ofSeconds(5))
                    .buildAsync(
                            URI.create("ws://localhost:" + port + "/ws?ticket=" + issueWebSocketTicket(session.accessToken())),
                            listener
                    )
                    .join();

            socket.sendText(
                    objectMapper.writeValueAsString(Map.of(
                            "type", "SUBSCRIBE",
                            "payload", Map.of("channelId", channel.id())
                    )),
                    true
            ).join();

            assertThat(awaitMessages(listener.messages(), 1))
                    .singleElement()
                    .satisfies(message -> assertThat(message).contains("\"type\":\"SUBSCRIBED\""));

            var content = "@assistant summarize architecture changes " + System.nanoTime();
            socket.sendText(
                    objectMapper.writeValueAsString(Map.of(
                            "type", "CHAT_SEND",
                            "channelId", channel.id(),
                            "payload", Map.of("workspaceId", workspace.id(), "content", content)
                    )),
                    true
            ).join();

            var events = awaitMessagesUntil(
                    listener.messages(),
                    8,
                    collected -> containsEventType(collected, "ACK")
                            && containsEventType(collected, "MESSAGE_CREATED")
                            && containsEventType(collected, "AGENT_RUN_CREATED")
                            && containsRunStatus(collected, "RUNNING")
                            && containsRunStatus(collected, "COMPLETED")
                            && containsAgentMessage(collected, "assistant", content)
            );

            assertThat(events).anySatisfy(message -> assertThat(message).contains("\"type\":\"ACK\""));
            assertThat(events).anySatisfy(message -> assertThat(message).contains("\"type\":\"AGENT_RUN_CREATED\""));
            assertThat(events).anySatisfy(message -> assertThat(message).contains("\"type\":\"AGENT_RUN_UPDATED\""));

            var run = awaitCompletedAgentRun(session.accessToken(), workspace.id(), "assistant");
            assertThat(run.get("status")).isEqualTo("COMPLETED");
            assertThat(run.get("resultMessageId")).isNotNull();

            var messagesResponse = restTemplate.exchange(
                    "/api/v1/channels/" + channel.id() + "/messages",
                    HttpMethod.GET,
                    authenticatedEntity(session.accessToken()),
                    String.class
            );
            var messages = readJsonList(messagesResponse);
            assertThat(messages).anySatisfy(message -> {
                assertThat(message.get("senderUserId")).isEqualTo("agent:assistant");
                assertThat(((String) message.get("content"))).contains("[assistant]");
                assertThat(((String) message.get("content"))).contains(content);
            });
        } finally {
            if (socket != null) {
                socket.sendClose(WebSocket.NORMAL_CLOSURE, "done").join();
            }
        }
    }

    @Test
    void teamMentionFlowPublishesCollaborationLifecycleAcrossMultipleRounds() throws Exception {
        var session = loginDemoUser();
        var workspace = firstWorkspace(session.accessToken());
        var channel = channelByName(session.accessToken(), workspace.id(), "general");
        var listener = new QueueingWebSocketListener();
        WebSocket socket = null;
        try {
            socket = HttpClient.newHttpClient()
                    .newWebSocketBuilder()
                    .connectTimeout(Duration.ofSeconds(5))
                    .buildAsync(
                            URI.create("ws://localhost:" + port + "/ws?ticket=" + issueWebSocketTicket(session.accessToken())),
                            listener
                    )
                    .join();

            socket.sendText(
                    objectMapper.writeValueAsString(Map.of(
                            "type", "SUBSCRIBE",
                            "payload", Map.of("channelId", channel.id())
                    )),
                    true
            ).join();

            assertThat(awaitMessages(listener.messages(), 1))
                    .singleElement()
                    .satisfies(message -> assertThat(message).contains("\"type\":\"SUBSCRIBED\""));

            var content = "@team produce a joint launch plan " + System.nanoTime();
            socket.sendText(
                    objectMapper.writeValueAsString(Map.of(
                            "type", "CHAT_SEND",
                            "channelId", channel.id(),
                            "payload", Map.of("workspaceId", workspace.id(), "content", content)
                    )),
                    true
            ).join();

            var events = awaitMessagesUntil(
                    listener.messages(),
                    40,
                    collected -> containsEventType(collected, "ACK")
                            && containsEventType(collected, "COLLABORATION_STARTED")
                            && containsCollaborationRound(collected, 2)
                            && containsEventType(collected, "COLLABORATION_COMPLETED")
                            && containsAgentMessage(collected, "assistant", "Role strategy")
                            && containsAgentMessage(collected, "reviewer", "Role strategy")
            );

            assertThat(events).anySatisfy(message -> assertThat(message).contains("\"type\":\"COLLABORATION_STARTED\""));
            assertThat(events).anySatisfy(message -> assertThat(message).contains("\"type\":\"COLLABORATION_STEP\""));
            assertThat(events).anySatisfy(message -> assertThat(message).contains("\"type\":\"COLLABORATION_COMPLETED\""));

            var storedMessagesResponse = restTemplate.exchange(
                    "/api/v1/channels/" + channel.id() + "/messages",
                    HttpMethod.GET,
                    authenticatedEntity(session.accessToken()),
                    String.class
            );
            var storedMessages = readJsonList(storedMessagesResponse);
            var triggerMessage = storedMessages.stream()
                    .filter(message -> content.equals(message.get("content")))
                    .findFirst()
                    .orElseThrow(() -> new AssertionError("Expected trigger message to be stored"));

            var runsResponse = restTemplate.exchange(
                    "/api/v1/agent-runs?workspaceId=" + workspace.id(),
                    HttpMethod.GET,
                    authenticatedEntity(session.accessToken()),
                    String.class
            );
            var runs = readJsonList(runsResponse).stream()
                    .filter(run -> triggerMessage.get("id").equals(run.get("triggerMessageId")))
                    .toList();
            assertThat(runs).hasSize(4);
            assertThat(runs).extracting(run -> run.get("agentKey"))
                    .containsExactlyInAnyOrder("assistant", "assistant", "reviewer", "reviewer");
            assertThat(runs).allSatisfy(run -> assertThat(run.get("status")).isEqualTo("COMPLETED"));

            assertThat(storedMessages).anySatisfy(message -> {
                assertThat(message.get("senderUserId")).isEqualTo("agent:assistant");
                assertThat(((String) message.get("content"))).contains("Role strategy: You are the synthesizer.");
                assertThat(((String) message.get("content"))).contains("Round 2 of 2");
            });
            assertThat(storedMessages).anySatisfy(message -> {
                assertThat(message.get("senderUserId")).isEqualTo("agent:reviewer");
                assertThat(((String) message.get("content"))).contains("Role strategy: You are the critic.");
                assertThat(((String) message.get("content"))).contains("Prior agent contributions:");
            });
        } finally {
            if (socket != null) {
                socket.sendClose(WebSocket.NORMAL_CLOSURE, "done").join();
            }
        }
    }

    @Test
    void allAgentsTriggerDeduplicatesSpecialMentionsAndCompletesWithinRoundLimit() throws Exception {
        var session = loginDemoUser();
        var workspace = firstWorkspace(session.accessToken());
        var channel = channelByName(session.accessToken(), workspace.id(), "general");
        var content = "@all-agents @team compare rollout risks " + System.nanoTime();

        var sendResponse = restTemplate.exchange(
                "/api/v1/channels/" + channel.id() + "/messages",
                HttpMethod.POST,
                authenticatedJsonEntity(
                        session.accessToken(),
                        Map.of("workspaceId", workspace.id(), "content", content)
                ),
                String.class
        );

        assertThat(sendResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        var triggerMessageId = readJsonObject(sendResponse).get("id");
        assertThat(triggerMessageId).isInstanceOf(String.class);

        var runs = awaitAgentRunsForTrigger(session.accessToken(), workspace.id(), (String) triggerMessageId, 4);
        assertThat(runs).hasSize(4);
        assertThat(runs).extracting(run -> run.get("agentKey"))
                .containsExactlyInAnyOrder("assistant", "assistant", "reviewer", "reviewer");
        assertThat(runs).allSatisfy(run -> assertThat(run.get("status")).isEqualTo("COMPLETED"));
    }

    @Test
    void websocketSubscribeRejectsChannelsOutsideUserMembership() throws Exception {
        var session = loginDemoUser();
        var outsider = registerUser("outsider-" + System.nanoTime() + "@microflow.local");
        var outsiderWorkspace = firstWorkspace(outsider.accessToken());
        var outsiderChannel = firstChannel(outsider.accessToken(), outsiderWorkspace.id());
        var listener = new QueueingWebSocketListener();
        WebSocket socket = null;
        try {
            socket = HttpClient.newHttpClient()
                    .newWebSocketBuilder()
                    .connectTimeout(Duration.ofSeconds(5))
                    .buildAsync(
                            URI.create("ws://localhost:" + port + "/ws?ticket=" + issueWebSocketTicket(session.accessToken())),
                            listener
                    )
                    .join();

            socket.sendText(
                    objectMapper.writeValueAsString(Map.of(
                            "type", "SUBSCRIBE",
                            "payload", Map.of("channelId", outsiderChannel.id())
                    )),
                    true
            ).join();

            assertThat(awaitMessages(listener.messages(), 1))
                    .singleElement()
                    .satisfies(message -> {
                        assertThat(message).contains("\"type\":\"ERROR\"");
                        assertThat(message).contains("Channel access denied");
                    });
        } finally {
            if (socket != null) {
                socket.sendClose(WebSocket.NORMAL_CLOSURE, "done").join();
            }
        }
    }

    private AuthSession loginDemoUser() throws Exception {
        var response = restTemplate.postForEntity(
                "/api/v1/auth/login",
                Map.of("email", "demo@microflow.local", "password", "demo12345"),
                String.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        var payload = readJsonObject(response);
        return new AuthSession(
                (String) payload.get("accessToken"),
                (String) payload.get("userId")
        );
    }

    private AuthSession registerUser(String email) throws Exception {
        var response = restTemplate.postForEntity(
                "/api/v1/auth/register",
                Map.of(
                        "email", email,
                        "password", "strong-pass-123",
                        "displayName", "Outsider"
                ),
                String.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        var payload = readJsonObject(response);
        return new AuthSession(
                (String) payload.get("accessToken"),
                (String) payload.get("userId")
        );
    }

    private WorkspacePayload firstWorkspace(String accessToken) throws Exception {
        var response = restTemplate.exchange(
                "/api/v1/workspaces",
                HttpMethod.GET,
                authenticatedEntity(accessToken),
                String.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        var workspaces = readJsonList(response);
        assertThat(workspaces).isNotEmpty();
        var workspace = workspaces.getFirst();
        return new WorkspacePayload((String) workspace.get("id"), (String) workspace.get("name"));
    }

    private ChannelPayload firstChannel(String accessToken, String workspaceId) throws Exception {
        var response = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/channels",
                HttpMethod.GET,
                authenticatedEntity(accessToken),
                String.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        var channels = readJsonList(response);
        assertThat(channels).isNotEmpty();
        var channel = channels.getFirst();
        return new ChannelPayload((String) channel.get("id"), (String) channel.get("name"));
    }

    private ChannelPayload channelByName(String accessToken, String workspaceId, String expectedName) throws Exception {
        var response = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/channels",
                HttpMethod.GET,
                authenticatedEntity(accessToken),
                String.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        var channels = readJsonList(response);
        var channel = channels.stream()
                .filter(candidate -> expectedName.equals(candidate.get("name")))
                .findFirst()
                .orElseThrow(() -> new AssertionError("Expected channel %s".formatted(expectedName)));
        return new ChannelPayload((String) channel.get("id"), (String) channel.get("name"));
    }

    private Map<String, Object> awaitCompletedAgentRun(
            String accessToken,
            String workspaceId,
            String agentKey
    ) throws Exception {
        var deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        while (System.nanoTime() < deadline) {
            var response = restTemplate.exchange(
                    "/api/v1/agent-runs?workspaceId=" + workspaceId,
                    HttpMethod.GET,
                    authenticatedEntity(accessToken),
                    String.class
            );
            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
            var runs = readJsonList(response);
            for (var run : runs) {
                if (agentKey.equals(run.get("agentKey")) && "COMPLETED".equals(run.get("status"))) {
                    return run;
                }
            }
            Thread.sleep(100);
        }
        fail("Timed out waiting for completed agent run for %s".formatted(agentKey));
        return Map.of();
    }

    private List<Map<String, Object>> awaitAgentRunsForTrigger(
            String accessToken,
            String workspaceId,
            String triggerMessageId,
            int expectedRunCount
    ) throws Exception {
        var deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        while (System.nanoTime() < deadline) {
            var response = restTemplate.exchange(
                    "/api/v1/agent-runs?workspaceId=" + workspaceId,
                    HttpMethod.GET,
                    authenticatedEntity(accessToken),
                    String.class
            );
            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
            var runs = readJsonList(response).stream()
                    .filter(run -> triggerMessageId.equals(run.get("triggerMessageId")))
                    .toList();
            if (runs.size() == expectedRunCount
                    && runs.stream().allMatch(run -> "COMPLETED".equals(run.get("status")) || "FAILED".equals(run.get("status")))) {
                return runs;
            }
            Thread.sleep(100);
        }
        fail("Timed out waiting for %s runs for trigger %s".formatted(expectedRunCount, triggerMessageId));
        return List.of();
    }

    private HttpEntity<Void> authenticatedEntity(String accessToken) {
        var headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        return new HttpEntity<>(headers);
    }

    private String issueWebSocketTicket(String accessToken) throws Exception {
        var response = restTemplate.exchange(
                "/api/v1/auth/ws-ticket",
                HttpMethod.POST,
                authenticatedEntity(accessToken),
                String.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return (String) readJsonObject(response).get("ticket");
    }

    private HttpEntity<Map<String, Object>> authenticatedJsonEntity(
            String accessToken,
            Map<String, Object> body
    ) {
        var headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        headers.setContentType(MediaType.APPLICATION_JSON);
        return new HttpEntity<>(body, headers);
    }

    private Map<String, Object> readJsonObject(ResponseEntity<String> response) throws Exception {
        return readJsonObject(response.getBody());
    }

    private Map<String, Object> readJsonObject(String responseBody) throws Exception {
        return objectMapper.readValue(responseBody, new TypeReference<Map<String, Object>>() {
        });
    }

    private List<Map<String, Object>> readJsonList(ResponseEntity<String> response) throws Exception {
        return objectMapper.readValue(response.getBody(), new TypeReference<List<Map<String, Object>>>() {
        });
    }

    private List<String> awaitMessages(BlockingQueue<String> queue, int expectedCount) throws InterruptedException {
        var messages = new ArrayList<String>();
        var deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        while (messages.size() < expectedCount && System.nanoTime() < deadline) {
            var next = queue.poll(200, TimeUnit.MILLISECONDS);
            if (next != null) {
                messages.add(next);
            }
        }
        if (messages.size() < expectedCount) {
            fail("Timed out waiting for %s websocket messages, got %s".formatted(expectedCount, messages));
        }
        return messages;
    }

    private List<String> awaitMessagesUntil(
            BlockingQueue<String> queue,
            int maxMessages,
            Predicate<List<String>> predicate
    ) throws InterruptedException {
        var messages = new ArrayList<String>();
        var deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        while (System.nanoTime() < deadline && messages.size() < maxMessages) {
            var next = queue.poll(200, TimeUnit.MILLISECONDS);
            if (next != null) {
                messages.add(next);
                if (predicate.test(messages)) {
                    return messages;
                }
            }
        }
        fail("Timed out waiting for websocket condition, got %s".formatted(messages));
        return messages;
    }

    private boolean containsEventType(List<String> events, String eventType) {
        return events.stream().anyMatch(event -> event.contains("\"type\":\"" + eventType + "\""));
    }

    private boolean containsRunStatus(List<String> events, String status) {
        return events.stream().anyMatch(event ->
                event.contains("\"type\":\"AGENT_RUN_UPDATED\"") && event.contains("\"status\":\"" + status + "\""));
    }

    private boolean containsAgentMessage(List<String> events, String agentKey, String prompt) {
        return events.stream().anyMatch(event ->
                event.contains("\"type\":\"MESSAGE_CREATED\"")
                        && event.contains("\"senderUserId\":\"agent:" + agentKey + "\"")
                        && event.contains("["
                        + agentKey
                        + "]")
                        && event.contains(prompt));
    }

    private boolean containsCollaborationRound(List<String> events, int round) {
        return events.stream().anyMatch(event ->
                event.contains("\"type\":\"COLLABORATION_STEP\"")
                        && event.contains("\"round\":" + round));
    }

    private static Path createDatabasePath() {
        try {
            var path = Files.createTempFile("microflow-it-", ".db");
            Files.deleteIfExists(path);
            return path;
        } catch (IOException ex) {
            throw new IllegalStateException("Unable to allocate integration-test database", ex);
        }
    }

    private record AuthSession(String accessToken, String userId) {
    }

    private record WorkspacePayload(String id, String name) {
    }

    private record ChannelPayload(String id, String name) {
    }

    private static final class QueueingWebSocketListener implements WebSocket.Listener {

        private final BlockingQueue<String> messages = new LinkedBlockingQueue<>();

        BlockingQueue<String> messages() {
            return messages;
        }

        @Override
        public void onOpen(WebSocket webSocket) {
            webSocket.request(1);
        }

        @Override
        public CompletionStage<?> onText(WebSocket webSocket, CharSequence data, boolean last) {
            messages.add(data.toString());
            webSocket.request(1);
            return CompletableFuture.completedFuture(null);
        }
    }
}
