package com.microflow.bootstrap;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ImportRuntimeHints;

@SpringBootApplication(scanBasePackages = "com.microflow")
@ImportRuntimeHints(MicroFlowRuntimeHints.class)
public class MicroFlowApplication {

    public static void main(String[] args) {
        SpringApplication.run(MicroFlowApplication.class, args);
    }
}

