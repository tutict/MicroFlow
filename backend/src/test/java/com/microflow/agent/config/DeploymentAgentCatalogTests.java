package com.microflow.agent.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.groups.Tuple.tuple;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.file.Files;
import org.junit.jupiter.api.Test;

class DeploymentAgentCatalogTests {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void fallsBackToMockBindingsWhenMachineConfigIsMissing() {
        var properties = new DeploymentAgentProperties();
        properties.setConfigPath("missing-agents.json");
        properties.setOpenclawStateDir("missing-qclaw-state");

        var catalog = new DeploymentAgentCatalog(properties, objectMapper);
        var bindings = catalog.discover();

        assertThat(bindings)
                .extracting(DiscoveredAgentBinding::agentKey, DiscoveredAgentBinding::provider)
                .containsExactly(
                        tuple("assistant", "mock-openclaw"),
                        tuple("reviewer", "mock-openclaw")
                );
    }

    @Test
    void loadsBindingsFromDeploymentConfigFile() throws Exception {
        var configFile = Files.createTempFile("agents-", ".json");
        try {
            Files.writeString(configFile, """
                    {
                      "providers": [
                        {
                          "provider": "openclaw",
                          "endpointUrl": "http://127.0.0.1:8787",
                          "credential": "dev-token",
                          "agentKeys": ["assistant", "reviewer"]
                        },
                        {
                          "provider": "codeclaw",
                          "endpointUrl": "http://127.0.0.1:8790",
                          "agentKeys": ["architect"]
                        }
                      ]
                    }
                    """);

            var properties = new DeploymentAgentProperties();
            properties.setConfigPath(configFile.toString());
            properties.setFallbackMockEnabled(false);

            var catalog = new DeploymentAgentCatalog(properties, objectMapper);
            var bindings = catalog.discover();

            assertThat(bindings)
                    .extracting(
                            DiscoveredAgentBinding::agentKey,
                            DiscoveredAgentBinding::provider,
                            DiscoveredAgentBinding::endpointUrl
                    )
                    .containsExactly(
                            tuple("assistant", "openclaw", "http://127.0.0.1:8787"),
                            tuple("reviewer", "openclaw", "http://127.0.0.1:8787"),
                            tuple("architect", "codeclaw", "http://127.0.0.1:8790")
                    );
        } finally {
            Files.deleteIfExists(configFile);
        }
    }

    @Test
    void discoversLocalQClawGatewayWhenStateDirectoryExists() throws Exception {
        var stateDir = Files.createTempDirectory("qclaw-state");
        try {
            Files.writeString(stateDir.resolve("qclaw.json"), """
                    {
                      "port": 28789
                    }
                    """);
            Files.writeString(stateDir.resolve("openclaw.json"), """
                    {
                      "gateway": {
                        "auth": {
                          "mode": "token",
                          "token": "local-gateway-token"
                        }
                      }
                    }
                    """);

            var properties = new DeploymentAgentProperties();
            properties.setFallbackMockEnabled(false);
            properties.setOpenclawStateDir(stateDir.toString());

            var catalog = new DeploymentAgentCatalog(properties, objectMapper);
            var bindings = catalog.discover();

            assertThat(bindings)
                    .extracting(
                            DiscoveredAgentBinding::agentKey,
                            DiscoveredAgentBinding::provider,
                            DiscoveredAgentBinding::endpointUrl,
                            DiscoveredAgentBinding::credential
                    )
                    .containsExactly(
                            tuple("assistant", "openclaw", "http://127.0.0.1:28789", "local-gateway-token"),
                            tuple("reviewer", "openclaw", "http://127.0.0.1:28789", "local-gateway-token")
                    );
        } finally {
            Files.walk(stateDir)
                    .sorted((left, right) -> right.compareTo(left))
                    .forEach(path -> {
                        try {
                            Files.deleteIfExists(path);
                        } catch (Exception ignored) {
                            // best effort cleanup for temp files
                        }
                    });
        }
    }
}
