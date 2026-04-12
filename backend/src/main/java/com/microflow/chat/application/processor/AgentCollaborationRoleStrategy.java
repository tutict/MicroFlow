package com.microflow.chat.application.processor;

import com.microflow.agent.infrastructure.persistence.JdbcAgentRepository;
import java.util.Locale;
import org.springframework.stereotype.Component;

@Component
public class AgentCollaborationRoleStrategy {

    private final JdbcAgentRepository agentRepository;

    public AgentCollaborationRoleStrategy(JdbcAgentRepository agentRepository) {
        this.agentRepository = agentRepository;
    }

    public String instructionsFor(String workspaceId, String agentKey) {
        var configured = agentRepository.findRoleStrategy(workspaceId, agentKey);
        if (configured != null && !configured.isBlank()) {
            return configured.trim();
        }
        var normalized = agentKey == null ? "" : agentKey.trim().toLowerCase(Locale.ROOT);
        if (normalized.contains("review")
                || normalized.contains("critic")
                || normalized.contains("qa")
                || normalized.contains("test")) {
            return "You are the critic. Focus on risks, contradictions, edge cases, and what should be corrected.";
        }
        if (normalized.contains("architect")
                || normalized.contains("plan")
                || normalized.contains("lead")
                || normalized.contains("strategy")) {
            return "You are the planner. Provide structure, sequencing, and the minimum viable path to execution.";
        }
        if (normalized.contains("build")
                || normalized.contains("coder")
                || normalized.contains("dev")
                || normalized.contains("implement")) {
            return "You are the implementer. Convert ideas into concrete actions, interfaces, and delivery details.";
        }
        if (normalized.contains("release")
                || normalized.contains("deploy")
                || normalized.contains("ops")
                || normalized.contains("launch")) {
            return "You are the release captain. Focus on launch sequencing, dependencies, and readiness gates.";
        }
        if (normalized.contains("assistant")
                || normalized.contains("summar")
                || normalized.contains("facilitator")) {
            return "You are the synthesizer. Reconcile the thread, surface consensus, and keep the team response concise.";
        }
        return "You are a specialist collaborator. Add one useful angle that is not already covered by the others.";
    }
}
