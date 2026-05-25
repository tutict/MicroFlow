package com.microflow.common.config;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Named;
import jakarta.inject.Singleton;
import jakarta.annotation.PreDestroy;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

@ApplicationScoped
public class VirtualThreadConfiguration {

    private final ExecutorService virtualThreadExecutorService = Executors.newVirtualThreadPerTaskExecutor();

    @Produces
    @Singleton
    @Named("microflowVirtualThreadExecutor")
    ExecutorService virtualThreadExecutorService() {
        return virtualThreadExecutorService;
    }

    @PreDestroy
    void close() {
        virtualThreadExecutorService.close();
    }
}
