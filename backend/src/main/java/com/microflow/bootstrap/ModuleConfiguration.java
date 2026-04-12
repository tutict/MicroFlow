package com.microflow.bootstrap;

import com.microflow.agent.config.DeploymentAgentProperties;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration(proxyBeanMethods = false)
@EnableConfigurationProperties(DeploymentAgentProperties.class)
public class ModuleConfiguration {
}
