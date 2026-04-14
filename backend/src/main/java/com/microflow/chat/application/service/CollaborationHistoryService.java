package com.microflow.chat.application.service;

import com.microflow.chat.domain.model.CollaborationEventLog;
import com.microflow.chat.domain.model.CollaborationRunSummary;
import java.util.List;

public interface CollaborationHistoryService {

    List<CollaborationEventLog> listChannelHistory(String userId, String channelId, int limit);

    List<CollaborationRunSummary> listChannelRuns(String userId, String channelId, int limit);
}
