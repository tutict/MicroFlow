package com.microflow.agent.config;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import org.eclipse.microprofile.config.inject.ConfigProperty;

@ApplicationScoped
public class DeploymentAgentPropertiesProducer {

    @Produces
    DeploymentAgentProperties deploymentAgentProperties(
            @ConfigProperty(name = "microflow.agent.config-path", defaultValue = "./data/agents.json") String configPath,
            @ConfigProperty(name = "microflow.agent.config-json") Optional<String> configJson,
            @ConfigProperty(name = "microflow.agent.fallback-mock-enabled", defaultValue = "true") boolean fallbackMockEnabled,
            @ConfigProperty(name = "microflow.agent.openclaw-endpoint-url") Optional<String> openclawEndpointUrl,
            @ConfigProperty(name = "microflow.agent.openclaw-credential") Optional<String> openclawCredential,
            @ConfigProperty(name = "microflow.agent.openclaw-state-dir") Optional<String> openclawStateDir,
            @ConfigProperty(name = "microflow.agent.openclaw-agent-keys", defaultValue = "assistant,reviewer") String openclawAgentKeys,
            @ConfigProperty(name = "OPENCLAW_ENDPOINT_URL") Optional<String> legacyOpenclawEndpointUrl,
            @ConfigProperty(name = "OPENCLAW_CREDENTIAL") Optional<String> legacyOpenclawCredential,
            @ConfigProperty(name = "OPENCLAW_AGENT_KEYS") Optional<String> legacyOpenclawAgentKeys
    ) {
        var properties = new DeploymentAgentProperties();
        properties.setConfigPath(configPath);
        properties.setConfigJson(configJson.orElse(" "));
        properties.setFallbackMockEnabled(fallbackMockEnabled);
        properties.setOpenclawEndpointUrl(firstPresent(openclawEndpointUrl, legacyOpenclawEndpointUrl).orElse(" "));
        properties.setOpenclawCredential(firstPresent(openclawCredential, legacyOpenclawCredential).orElse(""));
        properties.setOpenclawStateDir(openclawStateDir.orElse(" "));
        properties.setOpenclawAgentKeys(splitList(legacyOpenclawAgentKeys.orElse(openclawAgentKeys)));
        return properties;
    }

    private Optional<String> firstPresent(Optional<String> primary, Optional<String> fallback) {
        return primary.filter(value -> !value.isBlank()).or(() -> fallback.filter(value -> !value.isBlank()));
    }

    private List<String> splitList(String value) {
        if (value == null || value.isBlank()) {
            return List.of();
        }
        return Arrays.stream(value.split(","))
                .map(String::trim)
                .filter(item -> !item.isBlank())
                .toList();
    }
}
