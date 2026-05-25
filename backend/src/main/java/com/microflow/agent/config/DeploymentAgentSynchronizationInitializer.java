package com.microflow.agent.config;

import com.microflow.bootstrap.schema.SchemaMaintenanceInitializer;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;

@ApplicationScoped
public class DeploymentAgentSynchronizationInitializer {

    private final DeploymentAgentCatalog deploymentAgentCatalog;
    private final JdbcWorkspaceRepository workspaceRepository;
    private final SchemaMaintenanceInitializer schemaMaintenanceInitializer;

    public DeploymentAgentSynchronizationInitializer(
            DeploymentAgentCatalog deploymentAgentCatalog,
            JdbcWorkspaceRepository workspaceRepository,
            SchemaMaintenanceInitializer schemaMaintenanceInitializer
    ) {
        this.deploymentAgentCatalog = deploymentAgentCatalog;
        this.workspaceRepository = workspaceRepository;
        this.schemaMaintenanceInitializer = schemaMaintenanceInitializer;
    }

    void synchronizeDeploymentAgents(@Observes StartupEvent event) {
        schemaMaintenanceInitializer.initializeSchema();
        var bindings = deploymentAgentCatalog.discover();
        if (bindings.isEmpty()) {
            return;
        }
        for (var workspaceId : workspaceRepository.findAllWorkspaceIds()) {
            workspaceRepository.syncConfiguredAgents(workspaceId, bindings);
        }
    }
}
