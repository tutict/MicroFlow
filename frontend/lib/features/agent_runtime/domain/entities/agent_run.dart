enum AgentRunStatus {
  queued,
  contextBuilding,
  running,
  waitingApproval,
  succeeded,
  failed,
  cancelled;

  static AgentRunStatus fromWire(String? value) {
    return switch (value) {
      'CONTEXT_BUILDING' => AgentRunStatus.contextBuilding,
      'RUNNING' => AgentRunStatus.running,
      'WAITING_APPROVAL' => AgentRunStatus.waitingApproval,
      'SUCCEEDED' => AgentRunStatus.succeeded,
      'FAILED' => AgentRunStatus.failed,
      'CANCELLED' => AgentRunStatus.cancelled,
      _ => AgentRunStatus.queued,
    };
  }

  /// A run still holding a worker or waiting on a human.
  bool get isActive =>
      this == queued ||
      this == contextBuilding ||
      this == running ||
      this == waitingApproval;

  bool get canRetry => this == failed;

  bool get canCancel => isActive;
}

class AgentRunSummary {
  const AgentRunSummary({
    required this.id,
    required this.workspaceId,
    required this.agentKey,
    required this.kind,
    required this.status,
    required this.goal,
    this.taskId,
    this.channelId,
    this.contextSummary,
    this.errorMessage,
    this.interruptionState,
    this.stepCount = 0,
    this.approvalWaitCount = 0,
    this.attemptCount = 0,
    this.pendingApprovalId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String workspaceId;
  final String? taskId;
  final String? channelId;
  final String agentKey;
  final String kind;
  final AgentRunStatus status;
  final String goal;
  final String? contextSummary;
  final String? errorMessage;
  final String? interruptionState;
  final int stepCount;
  final int approvalWaitCount;
  final int attemptCount;
  final String? pendingApprovalId;
  final String? createdAt;
  final String? updatedAt;

  bool get wasInterrupted => interruptionState == 'INTERRUPTED';

  bool get needsApproval =>
      status == AgentRunStatus.waitingApproval && pendingApprovalId != null;
}
