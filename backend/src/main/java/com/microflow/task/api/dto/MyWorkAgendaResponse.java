package com.microflow.task.api.dto;

import java.util.List;

public record MyWorkAgendaResponse(
        List<TaskResponse> actionable,
        List<TaskResponse> blocked,
        List<TaskResponse> awaitingOthers,
        List<TaskResponse> recentlyDone,
        List<TaskResponse> running,
        List<TaskResponse> waitingApproval,
        int actionableCount,
        int blockedCount,
        int awaitingOthersCount,
        int runningCount,
        int waitingApprovalCount
) {
}
