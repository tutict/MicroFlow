package com.microflow.common.config;

import com.microflow.agent.config.DeploymentAgentCatalog;
import com.microflow.auth.infrastructure.persistence.JdbcUserRepository;
import com.microflow.auth.infrastructure.security.PasswordHasher;
import com.microflow.bootstrap.schema.SchemaMaintenanceInitializer;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import org.eclipse.microprofile.config.inject.ConfigProperty;

@ApplicationScoped
public class SeedDataInitializer {

    private final JdbcUserRepository userRepository;
    private final PasswordHasher passwordHasher;
    private final JdbcWorkspaceRepository workspaceRepository;
    private final DeploymentAgentCatalog deploymentAgentCatalog;
    private final SchemaMaintenanceInitializer schemaMaintenanceInitializer;
    private final boolean demoEnabled;

    public SeedDataInitializer(
            JdbcUserRepository userRepository,
            PasswordHasher passwordHasher,
            JdbcWorkspaceRepository workspaceRepository,
            DeploymentAgentCatalog deploymentAgentCatalog,
            SchemaMaintenanceInitializer schemaMaintenanceInitializer,
            @ConfigProperty(name = "microflow.seed.demo-enabled", defaultValue = "false") boolean demoEnabled
    ) {
        this.userRepository = userRepository;
        this.passwordHasher = passwordHasher;
        this.workspaceRepository = workspaceRepository;
        this.deploymentAgentCatalog = deploymentAgentCatalog;
        this.schemaMaintenanceInitializer = schemaMaintenanceInitializer;
        this.demoEnabled = demoEnabled;
    }

    void seedDemoData(@Observes StartupEvent event) {
        schemaMaintenanceInitializer.initializeSchema();
        if (!demoEnabled) {
            return;
        }
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
    }
}
