package com.microflow.common.config;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.AsyncTaskExecutor;
import org.springframework.core.task.support.TaskExecutorAdapter;

@Configuration(proxyBeanMethods = false)
public class VirtualThreadConfiguration {

    @Bean(destroyMethod = "close")
    ExecutorService virtualThreadExecutorService() {
        return Executors.newVirtualThreadPerTaskExecutor();
    }

    @Bean
    AsyncTaskExecutor applicationTaskExecutor(ExecutorService virtualThreadExecutorService) {
        return new TaskExecutorAdapter(virtualThreadExecutorService);
    }
}

