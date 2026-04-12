package com.microflow.agent.config;

import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;

@Configuration(proxyBeanMethods = false)
public class DeploymentAgentSynchronizationConfiguration {

    @Bean
    @Order(Ordered.LOWEST_PRECEDENCE)
    ApplicationRunner synchronizeDeploymentAgents(
            DeploymentAgentCatalog deploymentAgentCatalog,
            JdbcWorkspaceRepository workspaceRepository
    ) {
        return args -> {
            var bindings = deploymentAgentCatalog.discover();
            if (bindings.isEmpty()) {
                return;
            }
            for (var workspaceId : workspaceRepository.findAllWorkspaceIds()) {
                workspaceRepository.syncConfiguredAgents(workspaceId, bindings);
            }
        };
    }
}
