package com.microflow.chat.application.processor;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.microflow.agent.infrastructure.persistence.JdbcAgentRepository;
import org.junit.jupiter.api.Test;

class AgentCollaborationRoleStrategyTest {

    @Test
    void configuredStrategyOverridesInferredStrategy() {
        var agentRepository = mock(JdbcAgentRepository.class);
        when(agentRepository.findRoleStrategy("ws_1", "assistant"))
                .thenReturn("You are the custom strategist.");

        var strategy = new AgentCollaborationRoleStrategy(agentRepository);

        assertThat(strategy.instructionsFor("ws_1", "assistant"))
                .isEqualTo("You are the custom strategist.");
    }

    @Test
    void releaseAgentsUseReleaseCaptainStrategyByDefault() {
        var agentRepository = mock(JdbcAgentRepository.class);
        when(agentRepository.findRoleStrategy("ws_1", "release-manager"))
                .thenReturn(null);

        var strategy = new AgentCollaborationRoleStrategy(agentRepository);

        assertThat(strategy.instructionsFor("ws_1", "release-manager"))
                .isEqualTo("You are the release captain. Focus on launch sequencing, dependencies, and readiness gates.");
    }
}
