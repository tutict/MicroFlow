package com.microflow.chat.application.processor;

import com.microflow.agent.domain.gateway.AgentGateway;
import com.microflow.agent.domain.model.AgentExecutionRequest;
import com.microflow.chat.domain.model.ChatMessage;
import com.microflow.chat.infrastructure.persistence.JdbcMessageRepository;
import com.microflow.agent.infrastructure.persistence.JdbcAgentRepository;
import com.microflow.realtime.broadcaster.RealtimeBroadcaster;
import com.microflow.realtime.protocol.RealtimeEvent;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class AgentCollaborationOrchestrator {

    private static final Pattern COLLABORATION_TRIGGER_PATTERN = Pattern.compile("(?i)@(team|all-agents)\\b");

    private final JdbcAgentRepository agentRepository;
    private final JdbcMessageRepository messageRepository;
    private final AgentGateway agentGateway;
    private final RealtimeBroadcaster realtimeBroadcaster;
    private final AgentCollaborationRoleStrategy roleStrategy;
    private final int maxRounds;

    public AgentCollaborationOrchestrator(
            JdbcAgentRepository agentRepository,
            JdbcMessageRepository messageRepository,
            AgentGateway agentGateway,
            RealtimeBroadcaster realtimeBroadcaster,
            AgentCollaborationRoleStrategy roleStrategy,
            @Value("${microflow.chat.collaboration-max-rounds:2}") int maxRounds
    ) {
        this.agentRepository = agentRepository;
        this.messageRepository = messageRepository;
        this.agentGateway = agentGateway;
        this.realtimeBroadcaster = realtimeBroadcaster;
        this.roleStrategy = roleStrategy;
        this.maxRounds = Math.max(1, maxRounds);
    }

    public void orchestrate(ChatMessage triggerMessage, List<String> requestedAgentKeys, String triggerToken) {
        var collaborationId = "col_" + UUID.randomUUID();
        var agentKeys = requestedAgentKeys.stream()
                .filter(agentKey -> agentRepository.existsAgent(triggerMessage.workspaceId(), agentKey))
                .distinct()
                .toList();
        if (agentKeys.isEmpty()) {
            publishEvent(
                    triggerMessage.channelId(),
                    "COLLABORATION_ABORTED",
                    collaborationPayload(triggerMessage, collaborationId, triggerToken, 0, Map.of(
                            "reason", "NO_AVAILABLE_AGENTS"
                    ))
            );
            return;
        }

        for (var agentKey : agentKeys) {
            messageRepository.saveMention(triggerMessage.id(), agentKey);
        }

        publishEvent(
                triggerMessage.channelId(),
                "COLLABORATION_STARTED",
                collaborationPayload(triggerMessage, collaborationId, triggerToken, 0, Map.of(
                        "agentKeys", agentKeys,
                        "maxRounds", maxRounds
                ))
        );

        var transcript = new ArrayList<CollaborationTurn>();
        var executedRuns = 0;
        for (var round = 1; round <= maxRounds; round++) {
            var roundTurns = new ArrayList<CollaborationTurn>();
            for (var agentKey : agentKeys) {
                var prompt = buildPrompt(triggerMessage, triggerToken, round, transcript, agentKey);
                var runId = agentRepository.createRun(
                        triggerMessage.workspaceId(),
                        triggerMessage.channelId(),
                        triggerMessage.id(),
                        agentKey
                );
                executedRuns++;
                publishEvent(
                        triggerMessage.channelId(),
                        "AGENT_RUN_CREATED",
                        Map.of(
                                "runId", runId,
                                "agentKey", agentKey,
                                "status", "QUEUED",
                                "collaborationId", collaborationId,
                                "round", round
                        )
                );
                publishEvent(
                        triggerMessage.channelId(),
                        "COLLABORATION_STEP",
                        collaborationPayload(triggerMessage, collaborationId, triggerToken, round, Map.of(
                                "agentKey", agentKey,
                                "status", "RUNNING",
                                "runId", runId
                        ))
                );
                var turn = executeTurn(triggerMessage, collaborationId, triggerToken, round, agentKey, prompt, runId);
                if (turn != null) {
                    roundTurns.add(turn);
                }
            }

            if (roundTurns.isEmpty()) {
                publishEvent(
                        triggerMessage.channelId(),
                        "COLLABORATION_ABORTED",
                        collaborationPayload(triggerMessage, collaborationId, triggerToken, round, Map.of(
                                "reason", "NO_SUCCESSFUL_AGENT_RESPONSES",
                                "executedRuns", executedRuns
                        ))
                );
                return;
            }
            transcript.addAll(roundTurns);
        }

        publishEvent(
                triggerMessage.channelId(),
                "COLLABORATION_COMPLETED",
                collaborationPayload(triggerMessage, collaborationId, triggerToken, maxRounds, Map.of(
                        "executedRuns", executedRuns,
                        "agentKeys", agentKeys
                ))
        );
    }

    private CollaborationTurn executeTurn(
            ChatMessage triggerMessage,
            String collaborationId,
            String triggerToken,
            int round,
            String agentKey,
            String prompt,
            String runId
    ) {
        agentRepository.markStarted(runId);
        publishEvent(
                triggerMessage.channelId(),
                "AGENT_RUN_UPDATED",
                Map.of(
                        "runId", runId,
                        "status", "RUNNING",
                        "collaborationId", collaborationId,
                        "round", round
                )
        );
        try {
            var result = agentGateway.execute(new AgentExecutionRequest(
                    triggerMessage.workspaceId(),
                    triggerMessage.channelId(),
                    agentKey,
                    prompt,
                    Map.of(
                            "triggerMessageId", triggerMessage.id(),
                            "collaborationId", collaborationId,
                            "collaborationRound", round,
                            "collaborationTrigger", triggerToken
                    )
            ));
            if (!result.success()) {
                throw new IllegalStateException(result.errorMessage());
            }
            var responseMessage = messageRepository.saveAgentMessage(
                    triggerMessage.workspaceId(),
                    triggerMessage.channelId(),
                    agentKey,
                    result.output()
            );
            agentRepository.markCompleted(runId, responseMessage.id());
            publishEvent(triggerMessage.channelId(), "MESSAGE_CREATED", responseMessage);
            publishEvent(
                    triggerMessage.channelId(),
                    "AGENT_RUN_UPDATED",
                    Map.of(
                            "runId", runId,
                            "status", "COMPLETED",
                            "collaborationId", collaborationId,
                            "round", round
                    )
            );
            publishEvent(
                    triggerMessage.channelId(),
                    "COLLABORATION_STEP",
                    collaborationPayload(triggerMessage, collaborationId, triggerToken, round, Map.of(
                            "agentKey", agentKey,
                            "status", "COMPLETED",
                            "runId", runId,
                            "messageId", responseMessage.id()
                    ))
            );
            return new CollaborationTurn(agentKey, summarize(result.output()));
        } catch (Exception ex) {
            var errorMessage = ex.getMessage() == null ? ex.getClass().getSimpleName() : ex.getMessage();
            agentRepository.markFailed(runId, errorMessage);
            publishEvent(
                    triggerMessage.channelId(),
                    "AGENT_RUN_UPDATED",
                    Map.of(
                            "runId", runId,
                            "status", "FAILED",
                            "error", errorMessage,
                            "collaborationId", collaborationId,
                            "round", round
                    )
            );
            publishEvent(
                    triggerMessage.channelId(),
                    "COLLABORATION_STEP",
                    collaborationPayload(triggerMessage, collaborationId, triggerToken, round, Map.of(
                            "agentKey", agentKey,
                            "status", "FAILED",
                            "runId", runId,
                            "detail", errorMessage
                    ))
            );
            return null;
        }
    }

    private String buildPrompt(
            ChatMessage triggerMessage,
            String triggerToken,
            int round,
            List<CollaborationTurn> transcript,
            String agentKey
    ) {
        var prompt = new StringBuilder();
        prompt.append("You are participating in a MicroFlow multi-agent collaboration.\n");
        prompt.append("Trigger: ").append(triggerToken).append('\n');
        prompt.append("Round ").append(round).append(" of ").append(maxRounds).append('\n');
        prompt.append("Agent identity: @").append(agentKey).append('\n');
        prompt.append("Role strategy: ").append(roleStrategy.instructionsFor(triggerMessage.workspaceId(), agentKey)).append("\n\n");
        prompt.append("User request:\n");
        prompt.append(stripCollaborationTrigger(triggerMessage.content())).append("\n\n");
        if (!transcript.isEmpty()) {
            prompt.append("Prior agent contributions:\n");
            for (var turn : transcript) {
                prompt.append("- @")
                        .append(turn.agentKey())
                        .append(": ")
                        .append(turn.summary())
                        .append('\n');
            }
            prompt.append('\n');
        }
        prompt.append("Response rules:\n");
        prompt.append("- Contribute one distinct step forward.\n");
        prompt.append("- Avoid repeating the exact points already covered.\n");
        prompt.append("- Keep it concise and directly useful for a shared team thread.");
        return prompt.toString();
    }

    private String stripCollaborationTrigger(String rawMessage) {
        if (rawMessage == null || rawMessage.isBlank()) {
            return "";
        }
        return COLLABORATION_TRIGGER_PATTERN.matcher(rawMessage)
                .replaceAll("")
                .trim()
                .replaceAll("\\s+", " ");
    }

    private String summarize(String output) {
        var normalized = output == null ? "" : output.trim().replaceAll("\\s+", " ");
        if (normalized.length() <= 180) {
            return normalized;
        }
        return normalized.substring(0, 180) + "...";
    }

    private Map<String, Object> collaborationPayload(
            ChatMessage triggerMessage,
            String collaborationId,
            String triggerToken,
            int round,
            Map<String, Object> extra
    ) {
        var payload = new LinkedHashMap<String, Object>();
        payload.put("collaborationId", collaborationId);
        payload.put("workspaceId", triggerMessage.workspaceId());
        payload.put("channelId", triggerMessage.channelId());
        payload.put("triggerMessageId", triggerMessage.id());
        payload.put("trigger", triggerToken);
        payload.put("round", round);
        payload.putAll(extra);
        return payload;
    }

    private void publishEvent(String channelId, String type, Object payload) {
        realtimeBroadcaster.publishToChannel(channelId, new RealtimeEvent(type, payload));
    }

    private record CollaborationTurn(
            String agentKey,
            String summary
    ) {
    }
}
