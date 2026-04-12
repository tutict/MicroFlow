package com.microflow.common.config;

import com.microflow.agent.config.DeploymentAgentCatalog;
import com.microflow.auth.infrastructure.persistence.JdbcUserRepository;
import com.microflow.auth.infrastructure.security.PasswordHasher;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration(proxyBeanMethods = false)
public class SeedDataConfiguration {

    @Bean
    @ConditionalOnProperty(value = "microflow.seed.demo-enabled", havingValue = "true")
    ApplicationRunner seedDemoData(
            JdbcUserRepository userRepository,
            PasswordHasher passwordHasher,
            JdbcWorkspaceRepository workspaceRepository,
            DeploymentAgentCatalog deploymentAgentCatalog
    ) {
        return args -> {
            var discoveredAgents = deploymentAgentCatalog.discover();
            var owner = userRepository.findByEmail("demo@microflow.local")
                    .orElseGet(() -> userRepository.create(
                            "demo@microflow.local",
                            passwordHasher.hash("demo12345"),
                            "Demo Builder"
                    ));
            var workspaceId = workspaceRepository.findOwnedWorkspaceId(owner.id());
            if (workspaceId == null) {
                workspaceId = workspaceRepository.createDefaultWorkspace(
                        owner.id(),
                        owner.displayName(),
                        discoveredAgents
                );
            } else {
                workspaceRepository.syncConfiguredAgents(workspaceId, discoveredAgents);
            }

            var productUser = userRepository.findByEmail("product@microflow.local")
                    .orElseGet(() -> userRepository.create(
                            "product@microflow.local",
                            passwordHasher.hash("demo12345"),
                            "Lena Product"
                    ));
            var opsUser = userRepository.findByEmail("ops@microflow.local")
                    .orElseGet(() -> userRepository.create(
                            "ops@microflow.local",
                            passwordHasher.hash("demo12345"),
                            "Noah Ops"
                    ));

            workspaceRepository.addMemberIfAbsent(workspaceId, productUser.id(), "MEMBER");
            workspaceRepository.addMemberIfAbsent(workspaceId, opsUser.id(), "MEMBER");
        };
    }
}
