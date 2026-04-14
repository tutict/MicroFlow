package com.microflow.chat.application.processor;

import com.microflow.agent.domain.gateway.AgentGateway;
import com.microflow.agent.domain.model.AgentExecutionRequest;
import com.microflow.agent.infrastructure.persistence.JdbcAgentRepository;
import com.microflow.chat.domain.model.ChatMessage;
import com.microflow.chat.infrastructure.persistence.JdbcMessageRepository;
import com.microflow.knowledge.application.service.KnowledgeBaseService;
import com.microflow.realtime.broadcaster.RealtimeBroadcaster;
import com.microflow.realtime.protocol.RealtimeEvent;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
public class MentionDrivenMessageProcessor implements MessageProcessor {
    private static final Logger log = LoggerFactory.getLogger(MentionDrivenMessageProcessor.class);

    private static final String TEAM_TRIGGER = "team";
    private static final String ALL_AGENTS_TRIGGER = "all-agents";

    private final JdbcAgentRepository agentRepository;
    private final JdbcMessageRepository messageRepository;
    private final AgentGateway agentGateway;
    private final RealtimeBroadcaster realtimeBroadcaster;
    private final ExecutorService virtualThreadExecutorService;
    private final MentionParser mentionParser;
    private final AgentCollaborationOrchestrator collaborationOrchestrator;
    private final KnowledgeBaseService knowledgeBaseService;

    public MentionDrivenMessageProcessor(
            JdbcAgentRepository agentRepository,
            JdbcMessageRepository messageRepository,
            AgentGateway agentGateway,
            RealtimeBroadcaster realtimeBroadcaster,
            ExecutorService virtualThreadExecutorService,
            MentionParser mentionParser,
            AgentCollaborationOrchestrator collaborationOrchestrator,
            KnowledgeBaseService knowledgeBaseService
    ) {
        this.agentRepository = agentRepository;
        this.messageRepository = messageRepository;
        this.agentGateway = agentGateway;
        this.realtimeBroadcaster = realtimeBroadcaster;
        this.virtualThreadExecutorService = virtualThreadExecutorService;
        this.mentionParser = mentionParser;
        this.collaborationOrchestrator = collaborationOrchestrator;
        this.knowledgeBaseService = knowledgeBaseService;
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
            virtualThreadExecutorService.submit(() -> {
                try {
                    collaborationOrchestrator.orchestrate(
                            message,
                            teamAgentKeys,
                            collaborationTrigger
                    );
                } catch (Exception ex) {
                    log.error("Collaboration orchestration failed for channel {}", message.channelId(), ex);
                }
            });
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
                    buildPrompt(message, agentKey),
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

    private String buildPrompt(ChatMessage message, String agentKey) {
        var prompt = new StringBuilder();
        prompt.append("You are responding in a MicroFlow workspace channel.\n");
        prompt.append("Agent identity: @").append(agentKey).append("\n");
        prompt.append("Workspace id: ").append(message.workspaceId()).append("\n");
        prompt.append("Channel id: ").append(message.channelId()).append("\n\n");
        var knowledgeContext = knowledgeBaseService.buildContextBlock(
                message.workspaceId(),
                message.channelId(),
                message.content()
        );
        if (!knowledgeContext.isBlank()) {
            prompt.append(knowledgeContext).append("\n\n");
        }
        prompt.append("User request:\n");
        prompt.append(message.content()).append("\n\n");
        prompt.append("Response rules:\n");
        prompt.append("- Use uploaded workspace knowledge when it is relevant.\n");
        prompt.append("- Cite workspace sources inline as [kb:documentId] when you rely on them.\n");
        prompt.append("- Keep the answer actionable for the shared team thread.");
        return prompt.toString();
    }
}
