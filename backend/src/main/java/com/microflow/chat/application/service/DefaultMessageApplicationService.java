package com.microflow.chat.application.service;

import com.microflow.chat.application.processor.MessageProcessor;
import com.microflow.chat.domain.model.ChatMessage;
import com.microflow.chat.infrastructure.persistence.JdbcMessageRepository;
import com.microflow.realtime.broadcaster.RealtimeBroadcaster;
import com.microflow.realtime.protocol.RealtimeEvent;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class DefaultMessageApplicationService implements MessageApplicationService {

    private final JdbcMessageRepository messageRepository;
    private final JdbcWorkspaceRepository workspaceRepository;
    private final RealtimeBroadcaster realtimeBroadcaster;
    private final MessageProcessor messageProcessor;
    private final int maxMessageLength;
    private final int maxListLimit;

    public DefaultMessageApplicationService(
            JdbcMessageRepository messageRepository,
            JdbcWorkspaceRepository workspaceRepository,
            RealtimeBroadcaster realtimeBroadcaster,
            MessageProcessor messageProcessor,
            @Value("${microflow.chat.message.max-content-length:4000}") int maxMessageLength,
            @Value("${microflow.chat.message.max-list-limit:200}") int maxListLimit
    ) {
        this.messageRepository = messageRepository;
        this.workspaceRepository = workspaceRepository;
        this.realtimeBroadcaster = realtimeBroadcaster;
        this.messageProcessor = messageProcessor;
        this.maxMessageLength = Math.max(1, maxMessageLength);
        this.maxListLimit = Math.max(1, maxListLimit);
    }

    @Override
    public ChatMessage sendMessage(String workspaceId, String channelId, String senderUserId, String content) {
        validateMessageContent(content);
        if (!workspaceRepository.isWorkspaceMember(workspaceId, senderUserId)) {
            throw new IllegalArgumentException("Workspace access denied");
        }
        if (!workspaceRepository.isChannelMember(channelId, senderUserId)) {
            throw new IllegalArgumentException("Channel access denied");
        }
        var message = messageRepository.saveUserMessage(workspaceId, channelId, senderUserId, content);
        realtimeBroadcaster.publishToChannel(channelId, new RealtimeEvent("MESSAGE_CREATED", message));
        messageProcessor.process(message);
        return message;
    }

    @Override
    public List<ChatMessage> listMessages(String userId, String channelId, int limit) {
        if (!workspaceRepository.isChannelMember(channelId, userId)) {
            throw new IllegalArgumentException("Channel access denied");
        }
        return messageRepository.findByChannel(channelId, Math.min(Math.max(limit, 1), maxListLimit));
    }

    private void validateMessageContent(String content) {
        if (content == null || content.trim().isBlank()) {
            throw new IllegalArgumentException("Message content is required");
        }
        if (content.length() > maxMessageLength) {
            throw new IllegalArgumentException(
                    "Message content must be %s characters or fewer".formatted(maxMessageLength)
            );
        }
    }
}
