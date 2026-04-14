package com.microflow.chat.api.rest;

import com.microflow.chat.api.dto.CollaborationEventResponse;
import com.microflow.chat.api.dto.CollaborationRunResponse;
import com.microflow.chat.api.dto.MessageResponse;
import com.microflow.chat.api.dto.SendMessageRequest;
import com.microflow.chat.api.mapper.ChatApiMapper;
import com.microflow.chat.application.service.CollaborationHistoryService;
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
    private final CollaborationHistoryService collaborationHistoryService;
    private final ChatApiMapper chatApiMapper;

    public MessageController(
            MessageApplicationService messageApplicationService,
            CollaborationHistoryService collaborationHistoryService,
            ChatApiMapper chatApiMapper
    ) {
        this.messageApplicationService = messageApplicationService;
        this.collaborationHistoryService = collaborationHistoryService;
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

    @GetMapping("/{channelId}/collaboration-history")
    public List<CollaborationEventResponse> listCollaborationHistory(
            @PathVariable String channelId,
            HttpServletRequest httpRequest,
            @RequestParam(defaultValue = "50") int limit
    ) {
        var userId = (String) httpRequest.getAttribute("currentUserId");
        return collaborationHistoryService.listChannelHistory(userId, channelId, limit).stream()
                .map(chatApiMapper::toResponse)
                .toList();
    }

    @GetMapping("/{channelId}/collaboration-runs")
    public List<CollaborationRunResponse> listCollaborationRuns(
            @PathVariable String channelId,
            HttpServletRequest httpRequest,
            @RequestParam(defaultValue = "12") int limit
    ) {
        var userId = (String) httpRequest.getAttribute("currentUserId");
        return collaborationHistoryService.listChannelRuns(userId, channelId, limit).stream()
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
