package com.microflow.agent.infrastructure.provider.openclaw;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.microflow.agent.domain.model.AgentExecutionRequest;
import com.microflow.agent.domain.model.AgentExecutionTarget;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.http.HttpClient;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

class OpenClawHttpAgentGatewayTests {

    private HttpServer server;

    @AfterEach
    void tearDown() {
        if (server != null) {
            server.stop(0);
        }
    }

    @Test
    void sendsChatCompletionRequestAndFallsBackToMainAgentWhenNamedAgentIsMissing() throws Exception {
        var calls = new AtomicInteger();
        server = HttpServer.create(new InetSocketAddress(0), 0);
        server.createContext("/v1/chat/completions", exchange -> {
            calls.incrementAndGet();
            if (!"Bearer secret-token".equals(exchange.getRequestHeaders().getFirst("Authorization"))) {
                respond(exchange, 401, "{\"error\":\"unauthorized\"}");
                return;
            }
            var agentId = exchange.getRequestHeaders().getFirst("x-openclaw-agent-id");
            if ("assistant".equals(agentId)) {
                respond(exchange, 404, "{\"error\":\"unknown agent\"}");
                return;
            }
            assertThat(agentId).isEqualTo("main");
            assertThat(exchange.getRequestHeaders().getFirst("x-openclaw-session-key"))
                    .isEqualTo("microflow:ws_1:chn_1:assistant");
            var body = new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
            assertThat(body).contains("\"model\":\"openclaw\"");
            assertThat(body).contains("\"content\":\"Reply with OK\"");
            respond(exchange, 200, """
                    {
                      "choices": [
                        {
                          "message": {
                            "content": "OK"
                          }
                        }
                      ]
                    }
                    """);
        });
        server.start();

        var gateway = new OpenClawHttpAgentGateway(
                HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(2)).build(),
                new ObjectMapper()
        );
        var result = gateway.execute(
                new AgentExecutionRequest("ws_1", "chn_1", "assistant", "Reply with OK", Map.of()),
                new AgentExecutionTarget(
                        "openclaw",
                        "http://127.0.0.1:" + server.getAddress().getPort(),
                        "secret-token"
                )
        );

        assertThat(result.success()).isTrue();
        assertThat(result.output()).isEqualTo("OK");
        assertThat(calls.get()).isEqualTo(2);
    }

    private void respond(HttpExchange exchange, int status, String body) throws IOException {
        var bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.sendResponseHeaders(status, bytes.length);
        try (var output = exchange.getResponseBody()) {
            output.write(bytes);
        }
    }
}
