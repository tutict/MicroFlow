import '../../domain/entities/agent_run.dart';

class AgentRunDto {
  const AgentRunDto({
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
  final String status;
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

  factory AgentRunDto.fromJson(Map<String, Object?> json) {
    return AgentRunDto(
      id: json['id'] as String? ?? '',
      workspaceId: json['workspaceId'] as String? ?? '',
      taskId: json['taskId'] as String?,
      channelId: json['channelId'] as String?,
      agentKey: json['agentKey'] as String? ?? '',
      kind: json['kind'] as String? ?? 'TASK',
      status: json['status'] as String? ?? 'QUEUED',
      goal: json['goal'] as String? ?? '',
      contextSummary: json['contextSummary'] as String?,
      errorMessage: json['errorMessage'] as String?,
      interruptionState: json['interruptionState'] as String?,
      stepCount: (json['stepCount'] as num?)?.toInt() ?? 0,
      approvalWaitCount: (json['approvalWaitCount'] as num?)?.toInt() ?? 0,
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      pendingApprovalId: json['pendingApprovalId'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  AgentRunSummary toDomain() {
    return AgentRunSummary(
      id: id,
      workspaceId: workspaceId,
      taskId: taskId,
      channelId: channelId,
      agentKey: agentKey,
      kind: kind,
      status: AgentRunStatus.fromWire(status),
      goal: goal,
      contextSummary: contextSummary,
      errorMessage: errorMessage,
      interruptionState: interruptionState,
      stepCount: stepCount,
      approvalWaitCount: approvalWaitCount,
      attemptCount: attemptCount,
      pendingApprovalId: pendingApprovalId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
