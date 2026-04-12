package com.microflow.chat.application.processor;

import com.microflow.agent.domain.gateway.AgentGateway;
import com.microflow.agent.domain.model.AgentExecutionRequest;
import com.microflow.agent.infrastructure.persistence.JdbcAgentRepository;
import com.microflow.chat.domain.model.ChatMessage;
import com.microflow.chat.infrastructure.persistence.JdbcMessageRepository;
import com.microflow.realtime.broadcaster.RealtimeBroadcaster;
import com.microflow.realtime.protocol.RealtimeEvent;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import org.springframework.stereotype.Component;

@Component
public class MentionDrivenMessageProcessor implements MessageProcessor {

    private static final String TEAM_TRIGGER = "team";
    private static final String ALL_AGENTS_TRIGGER = "all-agents";

    private final JdbcAgentRepository agentRepository;
    private final JdbcMessageRepository messageRepository;
    private final AgentGateway agentGateway;
    private final RealtimeBroadcaster realtimeBroadcaster;
    private final ExecutorService virtualThreadExecutorService;
    private final MentionParser mentionParser;
    private final AgentCollaborationOrchestrator collaborationOrchestrator;

    public MentionDrivenMessageProcessor(
            JdbcAgentRepository agentRepository,
            JdbcMessageRepository messageRepository,
            AgentGateway agentGateway,
            RealtimeBroadcaster realtimeBroadcaster,
            ExecutorService virtualThreadExecutorService,
            MentionParser mentionParser,
            AgentCollaborationOrchestrator collaborationOrchestrator
    ) {
        this.agentRepository = agentRepository;
        this.messageRepository = messageRepository;
        this.agentGateway = agentGateway;
        this.realtimeBroadcaster = realtimeBroadcaster;
        this.virtualThreadExecutorService = virtualThreadExecutorService;
        this.mentionParser = mentionParser;
        this.collaborationOrchestrator = collaborationOrchestrator;
    }

    @Override
    public MessageProcessorResult process(ChatMessage message) {
        var boundAgentKey = agentRepository.findBoundAgentKeyForChannel(message.channelId());
        if (boundAgentKey != null) {
            return queueAgentRuns(message, List.of(boundAgentKey), false);
        }

        var mentions = mentionParser.parse(message.content());
        if (mentions.isEmpty()) {
            return MessageProcessorResult.empty();
        }

        var mentionedAgentKeys = mentions.stream()
                .map(ParsedAgentMention::agentKey)
                .distinct()
                .toList();
        var collaborationTrigger = resolveCollaborationTrigger(mentionedAgentKeys);
        if (collaborationTrigger != null) {
            var teamAgentKeys = agentRepository.listAgents(message.workspaceId()).stream()
                    .filter(agent -> agent.enabled())
                    .map(agent -> agent.agentKey())
                    .distinct()
                    .toList();
            if (teamAgentKeys.isEmpty()) {
                return MessageProcessorResult.empty();
            }
            virtualThreadExecutorService.submit(() -> collaborationOrchestrator.orchestrate(
                    message,
                    teamAgentKeys,
                    collaborationTrigger
            ));
            return new MessageProcessorResult(teamAgentKeys, List.of());
        }
        return queueAgentRuns(message, mentionedAgentKeys, true);
    }

    private String resolveCollaborationTrigger(List<String> mentionedAgentKeys) {
        if (mentionedAgentKeys.contains(ALL_AGENTS_TRIGGER)) {
            return "@" + ALL_AGENTS_TRIGGER;
        }
        if (mentionedAgentKeys.contains(TEAM_TRIGGER)) {
            return "@" + TEAM_TRIGGER;
        }
        return null;
    }

    private MessageProcessorResult queueAgentRuns(
            ChatMessage message,
            List<String> requestedAgentKeys,
            boolean persistMention
    ) {
        var detectedAgents = new java.util.ArrayList<String>();
        var queuedRunIds = new java.util.ArrayList<String>();

        for (var agentKey : requestedAgentKeys) {
            if (!agentRepository.existsAgent(message.workspaceId(), agentKey)) {
                continue;
            }
            detectedAgents.add(agentKey);
            if (persistMention) {
                messageRepository.saveMention(message.id(), agentKey);
            }
            var runId = agentRepository.createRun(message.workspaceId(), message.channelId(), message.id(), agentKey);
            queuedRunIds.add(runId);
            realtimeBroadcaster.publishToChannel(
                    message.channelId(),
                    new RealtimeEvent("AGENT_RUN_CREATED", Map.of("runId", runId, "agentKey", agentKey, "status", "QUEUED"))
            );
            virtualThreadExecutorService.submit(() -> executeRun(message, agentKey, runId));
        }

        if (queuedRunIds.isEmpty()) {
            return MessageProcessorResult.empty();
        }

        return new MessageProcessorResult(List.copyOf(detectedAgents), List.copyOf(queuedRunIds));
    }

    private void executeRun(ChatMessage message, String agentKey, String runId) {
        agentRepository.markStarted(runId);
        realtimeBroadcaster.publishToChannel(
                message.channelId(),
                new RealtimeEvent("AGENT_RUN_UPDATED", Map.of("runId", runId, "status", "RUNNING"))
        );
        try {
            var result = agentGateway.execute(new AgentExecutionRequest(
                    message.workspaceId(),
                    message.channelId(),
                    agentKey,
                    message.content(),
                    Map.of("triggerMessageId", message.id())
            ));
            if (!result.success()) {
                throw new IllegalStateException(result.errorMessage());
            }
            var responseMessage = messageRepository.saveAgentMessage(
                    message.workspaceId(),
                    message.channelId(),
                    agentKey,
                    result.output()
            );
            agentRepository.markCompleted(runId, responseMessage.id());
            realtimeBroadcaster.publishToChannel(message.channelId(), new RealtimeEvent("MESSAGE_CREATED", responseMessage));
            realtimeBroadcaster.publishToChannel(
                    message.channelId(),
                    new RealtimeEvent("AGENT_RUN_UPDATED", Map.of("runId", runId, "status", "COMPLETED"))
            );
        } catch (Exception ex) {
            var errorMessage = ex.getMessage() == null ? ex.getClass().getSimpleName() : ex.getMessage();
            agentRepository.markFailed(runId, errorMessage);
            realtimeBroadcaster.publishToChannel(
                    message.channelId(),
                    new RealtimeEvent("AGENT_RUN_UPDATED", Map.of("runId", runId, "status", "FAILED", "error", errorMessage))
            );
        }
    }
}
