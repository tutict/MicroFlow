package com.microflow.chat.application.service;

import com.microflow.chat.domain.model.CollaborationEventLog;
import com.microflow.chat.domain.model.CollaborationRunSummary;
import com.microflow.chat.infrastructure.persistence.JdbcCollaborationHistoryRepository;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Arrays;
import org.springframework.stereotype.Service;

@Service
public class DefaultCollaborationHistoryService implements CollaborationHistoryService {

    private final JdbcCollaborationHistoryRepository collaborationHistoryRepository;
    private final JdbcWorkspaceRepository workspaceRepository;

    public DefaultCollaborationHistoryService(
            JdbcCollaborationHistoryRepository collaborationHistoryRepository,
            JdbcWorkspaceRepository workspaceRepository
    ) {
        this.collaborationHistoryRepository = collaborationHistoryRepository;
        this.workspaceRepository = workspaceRepository;
    }

    @Override
    public List<CollaborationEventLog> listChannelHistory(String userId, String channelId, int limit) {
        if (!workspaceRepository.isChannelMember(channelId, userId)) {
            throw new IllegalArgumentException("Channel access denied");
        }
        var normalizedLimit = Math.min(Math.max(limit, 1), 100);
        return collaborationHistoryRepository.listByChannel(channelId, normalizedLimit);
    }

    @Override
    public List<CollaborationRunSummary> listChannelRuns(String userId, String channelId, int limit) {
        if (!workspaceRepository.isChannelMember(channelId, userId)) {
            throw new IllegalArgumentException("Channel access denied");
        }
        var normalizedLimit = Math.min(Math.max(limit, 1), 50);
        var collaborationIds = collaborationHistoryRepository.listRecentCollaborationIds(channelId, normalizedLimit);
        if (collaborationIds.isEmpty()) {
            return List.of();
        }
        var events = collaborationHistoryRepository.listByChannelAndCollaborationIds(channelId, collaborationIds);
        var eventsByCollaborationId = new LinkedHashMap<String, List<CollaborationEventLog>>();
        for (var collaborationId : collaborationIds) {
            eventsByCollaborationId.put(collaborationId, new ArrayList<>());
        }
        for (var event : events) {
            eventsByCollaborationId.computeIfAbsent(event.collaborationId(), ignored -> new ArrayList<>()).add(event);
        }
        return collaborationIds.stream()
                .map(eventsByCollaborationId::get)
                .filter(group -> group != null && !group.isEmpty())
                .map(this::toRunSummary)
                .toList();
    }

    private CollaborationRunSummary toRunSummary(List<CollaborationEventLog> events) {
        var first = events.get(0);
        var latest = events.get(events.size() - 1);
        return new CollaborationRunSummary(
                latest.collaborationId(),
                latest.workspaceId(),
                latest.channelId(),
                latest.triggerMessageId() != null && !latest.triggerMessageId().isBlank()
                        ? latest.triggerMessageId()
                        : first.triggerMessageId(),
                latest.status(),
                latest.stage(),
                lastNonBlank(events, CollaborationEventLog::agentKey, latest.agentKey()),
                distinctAgentKeys(events),
                lastNonBlank(events, CollaborationEventLog::trigger, latest.trigger()),
                lastNonBlank(events, CollaborationEventLog::reason, latest.reason()),
                latest.round(),
                latest.maxRounds(),
                lastNonBlank(events, CollaborationEventLog::detail, latest.detail()),
                first.createdAt(),
                latest.createdAt(),
                List.copyOf(events)
        );
    }

    private String lastNonBlank(
            List<CollaborationEventLog> events,
            java.util.function.Function<CollaborationEventLog, String> extractor,
            String fallback
    ) {
        for (var index = events.size() - 1; index >= 0; index--) {
            var value = extractor.apply(events.get(index));
            if (value != null && !value.isBlank()) {
                return value;
            }
        }
        return fallback;
    }

    private List<String> distinctAgentKeys(List<CollaborationEventLog> events) {
        var ordered = new LinkedHashMap<String, Boolean>();
        for (var event : events) {
            if (event.agentKeys() != null && !event.agentKeys().isBlank()) {
                Arrays.stream(event.agentKeys().split(","))
                        .map(String::trim)
                        .filter(candidate -> !candidate.isEmpty())
                        .forEach(candidate -> ordered.putIfAbsent(candidate, Boolean.TRUE));
            }
            if (event.agentKey() != null && !event.agentKey().isBlank()) {
                ordered.putIfAbsent(event.agentKey(), Boolean.TRUE);
            }
        }
        return List.copyOf(ordered.keySet());
    }
}
