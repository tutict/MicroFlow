package com.microflow.agent.config;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
public class DeploymentAgentCatalog {

    private static final Logger log = LoggerFactory.getLogger(DeploymentAgentCatalog.class);
    private static final Pattern PORT_PATTERN = Pattern.compile("\"port\"\\s*:\\s*(\\d+)");
    private static final Pattern GATEWAY_TOKEN_PATTERN = Pattern.compile(
            "\"gateway\"\\s*:\\s*\\{.*?\"auth\"\\s*:\\s*\\{.*?\"mode\"\\s*:\\s*\"token\".*?\"token\"\\s*:\\s*\"([^\"]+)\"",
            Pattern.DOTALL
    );

    private final DeploymentAgentProperties properties;
    private final ObjectMapper objectMapper;

    public DeploymentAgentCatalog(DeploymentAgentProperties properties, ObjectMapper objectMapper) {
        this.properties = properties;
        this.objectMapper = objectMapper;
    }

    public List<DiscoveredAgentBinding> discover() {
        var candidates = new ArrayList<DiscoveredAgentBinding>();
        appendFromJson(candidates, properties.getConfigJson(), "microflow.agent.config-json");
        appendFromConfigPath(candidates);
        appendFromDefinitions(candidates, properties.getProviders(), "microflow.agent.providers");
        appendOpenClawShortcut(candidates);
        appendLocalOpenClawInstall(candidates);
        if (candidates.isEmpty() && properties.isFallbackMockEnabled()) {
            candidates.add(new DiscoveredAgentBinding(
                    "assistant",
                    "mock-openclaw",
                    "local://mock-openclaw",
                    ""
            ));
            candidates.add(new DiscoveredAgentBinding(
                    "reviewer",
                    "mock-openclaw",
                    "local://mock-openclaw",
                    ""
            ));
        }
        return deduplicateByAgentKey(candidates);
    }

    private void appendFromConfigPath(List<DiscoveredAgentBinding> candidates) {
        var rawPath = properties.getConfigPath();
        if (rawPath == null || rawPath.isBlank()) {
            return;
        }
        var path = Path.of(rawPath);
        if (!Files.exists(path)) {
            return;
        }
        try {
            appendFromJson(candidates, Files.readString(path), "config file " + path.toAbsolutePath());
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to read agent config file " + path.toAbsolutePath(), ex);
        }
    }

    private void appendOpenClawShortcut(List<DiscoveredAgentBinding> candidates) {
        if (properties.getOpenclawEndpointUrl() == null || properties.getOpenclawEndpointUrl().isBlank()) {
            return;
        }
        var definition = new DeploymentAgentProperties.ProviderDefinition();
        definition.setProvider("openclaw");
        definition.setEndpointUrl(properties.getOpenclawEndpointUrl());
        definition.setCredential(properties.getOpenclawCredential());
        definition.setAgentKeys(properties.getOpenclawAgentKeys());
        appendFromDefinitions(candidates, List.of(definition), "microflow.agent.openclaw-*");
    }

    private void appendLocalOpenClawInstall(List<DiscoveredAgentBinding> candidates) {
        if (properties.getOpenclawEndpointUrl() != null && !properties.getOpenclawEndpointUrl().isBlank()) {
            return;
        }
        var stateDir = resolveOpenClawStateDir();
        if (stateDir == null) {
            return;
        }

        var qclawConfigPath = stateDir.resolve("qclaw.json");
        var openclawConfigPath = stateDir.resolve("openclaw.json");
        if (!Files.exists(qclawConfigPath) && !Files.exists(openclawConfigPath)) {
            return;
        }

        var port = extractPort(qclawConfigPath);
        if (port == null) {
            port = extractPort(openclawConfigPath);
        }
        if (port == null) {
            return;
        }

        var definition = new DeploymentAgentProperties.ProviderDefinition();
        definition.setProvider("openclaw");
        definition.setEndpointUrl("http://127.0.0.1:" + port);
        definition.setCredential(extractGatewayToken(openclawConfigPath));
        definition.setAgentKeys(properties.getOpenclawAgentKeys());
        appendFromDefinitions(candidates, List.of(definition), "local qclaw state " + stateDir.toAbsolutePath());
    }

    private void appendFromJson(List<DiscoveredAgentBinding> candidates, String rawJson, String source) {
        if (rawJson == null || rawJson.isBlank()) {
            return;
        }
        try {
            var root = objectMapper.readTree(rawJson);
            var providersNode = root != null && root.isArray() ? root : root == null ? null : root.get("providers");
            if (providersNode == null || !providersNode.isArray()) {
                throw new IllegalStateException("Expected an array or {\"providers\": [...]} payload");
            }
            var definitions = new ArrayList<DeploymentAgentProperties.ProviderDefinition>();
            for (var providerNode : providersNode) {
                var definition = new DeploymentAgentProperties.ProviderDefinition();
                definition.setProvider(readText(providerNode, "provider"));
                definition.setEndpointUrl(readText(providerNode, "endpointUrl"));
                definition.setCredential(readTextOrEmpty(providerNode, "credential"));
                definition.setAgentKeys(readTextList(providerNode.get("agentKeys")));
                definitions.add(definition);
            }
            appendFromDefinitions(candidates, definitions, source);
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to parse agent configuration from " + source, ex);
        }
    }

    private void appendFromDefinitions(
            List<DiscoveredAgentBinding> candidates,
            List<DeploymentAgentProperties.ProviderDefinition> definitions,
            String source
    ) {
        for (var definition : definitions) {
            var provider = normalizeProvider(definition.getProvider());
            var endpointUrl = normalizeText(definition.getEndpointUrl());
            if (provider == null || endpointUrl == null) {
                log.warn("Skipping incomplete agent provider definition from {}", source);
                continue;
            }
            var credential = definition.getCredential() == null ? "" : definition.getCredential();
            for (var rawAgentKey : definition.getAgentKeys()) {
                var agentKey = normalizeAgentKey(rawAgentKey);
                if (agentKey == null) {
                    continue;
                }
                candidates.add(new DiscoveredAgentBinding(agentKey, provider, endpointUrl, credential));
            }
        }
    }

    private List<DiscoveredAgentBinding> deduplicateByAgentKey(List<DiscoveredAgentBinding> candidates) {
        var bindings = new LinkedHashMap<String, DiscoveredAgentBinding>();
        for (var candidate : candidates) {
            var existing = bindings.putIfAbsent(candidate.agentKey(), candidate);
            if (existing != null) {
                log.warn(
                        "Ignoring duplicate agent key {} from provider {} because {} already claimed it",
                        candidate.agentKey(),
                        candidate.provider(),
                        existing.provider()
                );
            }
        }
        return List.copyOf(bindings.values());
    }

    private String readText(JsonNode node, String fieldName) {
        var value = node == null ? null : node.get(fieldName);
        return value == null || value.isNull() ? null : value.asText(null);
    }

    private String readTextOrEmpty(JsonNode node, String fieldName) {
        var value = readText(node, fieldName);
        return value == null ? "" : value;
    }

    private List<String> readTextList(JsonNode node) {
        if (node == null || !node.isArray()) {
            return List.of();
        }
        var values = new ArrayList<String>();
        for (var entry : node) {
            if (entry != null && !entry.isNull()) {
                values.add(entry.asText());
            }
        }
        return values;
    }

    private String normalizeProvider(String value) {
        var normalized = normalizeText(value);
        return normalized == null ? null : normalized.toLowerCase(Locale.ROOT);
    }

    private String normalizeAgentKey(String value) {
        var normalized = normalizeText(value);
        return normalized == null ? null : normalized.toLowerCase(Locale.ROOT);
    }

    private String normalizeText(String value) {
        if (value == null) {
            return null;
        }
        var normalized = value.trim();
        return normalized.isEmpty() ? null : normalized;
    }

    private Path resolveOpenClawStateDir() {
        var configured = normalizeText(properties.getOpenclawStateDir());
        if (configured != null) {
            return Path.of(configured);
        }
        var userHome = System.getProperty("user.home");
        if (userHome == null || userHome.isBlank()) {
            return null;
        }
        return Path.of(userHome, ".qclaw");
    }

    private String extractPort(Path configPath) {
        var content = readFileIfExists(configPath);
        if (content == null) {
            return null;
        }
        var match = PORT_PATTERN.matcher(content);
        return match.find() ? match.group(1) : null;
    }

    private String extractGatewayToken(Path configPath) {
        var content = readFileIfExists(configPath);
        if (content == null) {
            return "";
        }
        var match = GATEWAY_TOKEN_PATTERN.matcher(content);
        return match.find() ? match.group(1) : "";
    }

    private String readFileIfExists(Path path) {
        if (path == null || !Files.exists(path)) {
            return null;
        }
        try {
            return Files.readString(path);
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to read OpenClaw config file " + path.toAbsolutePath(), ex);
        }
    }
}
