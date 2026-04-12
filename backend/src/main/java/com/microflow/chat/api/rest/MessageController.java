package com.microflow.chat.api.rest;

import com.microflow.chat.api.dto.MessageResponse;
import com.microflow.chat.api.dto.SendMessageRequest;
import com.microflow.chat.api.mapper.ChatApiMapper;
import com.microflow.chat.application.service.MessageApplicationService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/channels")
public class MessageController {

    private final MessageApplicationService messageApplicationService;
    private final ChatApiMapper chatApiMapper;

    public MessageController(MessageApplicationService messageApplicationService, ChatApiMapper chatApiMapper) {
        this.messageApplicationService = messageApplicationService;
        this.chatApiMapper = chatApiMapper;
    }

    @GetMapping("/{channelId}/messages")
    public List<MessageResponse> listMessages(
            @PathVariable String channelId,
            HttpServletRequest httpRequest,
            @RequestParam(defaultValue = "50") int limit
    ) {
        var userId = (String) httpRequest.getAttribute("currentUserId");
        return messageApplicationService.listMessages(userId, channelId, limit).stream()
                .map(chatApiMapper::toResponse)
                .toList();
    }

    @PostMapping("/{channelId}/messages")
    public MessageResponse sendMessage(
            @PathVariable String channelId,
            HttpServletRequest httpRequest,
            @Valid @RequestBody SendMessageRequest request
    ) {
        var userId = (String) httpRequest.getAttribute("currentUserId");
        var message = messageApplicationService.sendMessage(
                request.workspaceId(),
                channelId,
                userId,
                request.content()
        );
        return chatApiMapper.toResponse(message);
    }
}
