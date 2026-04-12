package com.microflow.common.config;

import java.nio.file.Files;
import java.nio.file.Path;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

@Configuration(proxyBeanMethods = false)
public class DataDirectoryInitializer {

    public DataDirectoryInitializer(@Value("${MICROFLOW_DATA_DIR:./data}") String dataDir) {
        try {
            Files.createDirectories(Path.of(dataDir));
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to create data directory", ex);
        }
    }
}
