package com.microflow.chat.application.service;

import com.microflow.chat.domain.model.ChatMessage;
import java.util.List;

public interface MessageApplicationService {

    ChatMessage sendMessage(String workspaceId, String channelId, String senderUserId, String content);

    List<ChatMessage> listMessages(String userId, String channelId, int limit);
}
