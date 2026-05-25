package com.microflow.common.config;

import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import java.nio.file.Files;
import java.nio.file.Path;
import org.eclipse.microprofile.config.inject.ConfigProperty;

@ApplicationScoped
public class DataDirectoryInitializer {

    @ConfigProperty(name = "MICROFLOW_DATA_DIR", defaultValue = "./data")
    String dataDir;

    void initialize(@Observes StartupEvent event) {
        try {
            Files.createDirectories(Path.of(dataDir));
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to create data directory", ex);
        }
    }
}
