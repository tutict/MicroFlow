package com.microflow.chat.api.mapper;

import com.microflow.chat.api.dto.CollaborationEventResponse;
import com.microflow.chat.api.dto.CollaborationRunResponse;
import com.microflow.chat.domain.model.CollaborationEventLog;
import com.microflow.chat.domain.model.CollaborationRunSummary;
import com.microflow.chat.api.dto.MessageResponse;
import com.microflow.chat.domain.model.ChatMessage;
import org.springframework.stereotype.Component;

@Component
public class ChatApiMapper {

    public MessageResponse toResponse(ChatMessage message) {
        return new MessageResponse(
                message.id(),
                message.workspaceId(),
                message.channelId(),
                message.senderUserId(),
                message.content(),
                message.createdAt().toString()
        );
    }

    public CollaborationEventResponse toResponse(CollaborationEventLog event) {
        return new CollaborationEventResponse(
                event.id(),
                event.workspaceId(),
                event.channelId(),
                event.collaborationId(),
                event.eventType(),
                event.status(),
                event.stage(),
                event.agentKey(),
                event.trigger(),
                event.round(),
                event.maxRounds(),
                event.detail(),
                event.createdAt()
        );
    }

    public CollaborationRunResponse toResponse(CollaborationRunSummary run) {
        return new CollaborationRunResponse(
                run.collaborationId(),
                run.workspaceId(),
                run.channelId(),
                run.triggerMessageId(),
                run.status(),
                run.stage(),
                run.activeAgentKey(),
                run.agentKeys(),
                run.trigger(),
                run.reason(),
                run.round(),
                run.maxRounds(),
                run.detail(),
                run.startedAt(),
                run.lastEventAt(),
                run.events().stream()
                        .map(this::toResponse)
                        .toList()
        );
    }
}
