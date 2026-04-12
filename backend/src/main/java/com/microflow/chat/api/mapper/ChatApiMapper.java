package com.microflow.chat.api.mapper;

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
}

