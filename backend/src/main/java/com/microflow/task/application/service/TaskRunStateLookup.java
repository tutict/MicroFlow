package com.microflow.task.application.service;

import java.util.List;
import java.util.Map;

/** Execution state relevant to task routing, without exposing the runtime's persistence model. */
public interface TaskRunStateLookup {
    Map<String, State> statesForTasks(String workspaceId, List<String> taskIds);

    enum State { RUNNING, WAITING_APPROVAL }
}
