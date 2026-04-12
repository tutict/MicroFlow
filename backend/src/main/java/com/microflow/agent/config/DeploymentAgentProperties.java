package com.microflow.agent.config;

import java.util.ArrayList;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "microflow.agent")
public class DeploymentAgentProperties {

    private String configPath = "./data/agents.json";
    private String configJson;
    private boolean fallbackMockEnabled = true;
    private String openclawEndpointUrl;
    private String openclawCredential = "";
    private String openclawStateDir;
    private List<String> openclawAgentKeys = new ArrayList<>(List.of("assistant", "reviewer"));
    private List<ProviderDefinition> providers = new ArrayList<>();

    public String getConfigPath() {
        return configPath;
    }

    public void setConfigPath(String configPath) {
        this.configPath = configPath;
    }

    public String getConfigJson() {
        return configJson;
    }

    public void setConfigJson(String configJson) {
        this.configJson = configJson;
    }

    public boolean isFallbackMockEnabled() {
        return fallbackMockEnabled;
    }

    public void setFallbackMockEnabled(boolean fallbackMockEnabled) {
        this.fallbackMockEnabled = fallbackMockEnabled;
    }

    public String getOpenclawEndpointUrl() {
        return openclawEndpointUrl;
    }

    public void setOpenclawEndpointUrl(String openclawEndpointUrl) {
        this.openclawEndpointUrl = openclawEndpointUrl;
    }

    public String getOpenclawCredential() {
        return openclawCredential;
    }

    public void setOpenclawCredential(String openclawCredential) {
        this.openclawCredential = openclawCredential;
    }

    public String getOpenclawStateDir() {
        return openclawStateDir;
    }

    public void setOpenclawStateDir(String openclawStateDir) {
        this.openclawStateDir = openclawStateDir;
    }

    public List<String> getOpenclawAgentKeys() {
        return openclawAgentKeys;
    }

    public void setOpenclawAgentKeys(List<String> openclawAgentKeys) {
        this.openclawAgentKeys = openclawAgentKeys == null ? new ArrayList<>() : new ArrayList<>(openclawAgentKeys);
    }

    public List<ProviderDefinition> getProviders() {
        return providers;
    }

    public void setProviders(List<ProviderDefinition> providers) {
        this.providers = providers == null ? new ArrayList<>() : new ArrayList<>(providers);
    }

    public static class ProviderDefinition {

        private String provider;
        private String endpointUrl;
        private String credential = "";
        private List<String> agentKeys = new ArrayList<>();

        public String getProvider() {
            return provider;
        }

        public void setProvider(String provider) {
            this.provider = provider;
        }

        public String getEndpointUrl() {
            return endpointUrl;
        }

        public void setEndpointUrl(String endpointUrl) {
            this.endpointUrl = endpointUrl;
        }

        public String getCredential() {
            return credential;
        }

        public void setCredential(String credential) {
            this.credential = credential;
        }

        public List<String> getAgentKeys() {
            return agentKeys;
        }

        public void setAgentKeys(List<String> agentKeys) {
            this.agentKeys = agentKeys == null ? new ArrayList<>() : new ArrayList<>(agentKeys);
        }
    }
}
