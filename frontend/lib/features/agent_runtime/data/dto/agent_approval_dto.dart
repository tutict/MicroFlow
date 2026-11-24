import '../../domain/entities/agent_approval.dart';

class AgentApprovalDto {
  const AgentApprovalDto({
    required this.id,
    required this.runId,
    required this.toolKey,
    required this.action,
    required this.riskLevel,
    required this.status,
    this.targetResource,
    this.impactSummary,
    this.input = const {},
    this.note,
    this.createdAt,
  });

  final String id;
  final String runId;
  final String toolKey;
  final String action;
  final String riskLevel;
  final String status;
  final String? targetResource;
  final String? impactSummary;
  final Map<String, Object?> input;
  final String? note;
  final String? createdAt;

  factory AgentApprovalDto.fromJson(Map<String, Object?> json) {
    final rawInput = json['input'];
    return AgentApprovalDto(
      id: json['id'] as String? ?? '',
      runId: json['runId'] as String? ?? '',
      toolKey: json['toolKey'] as String? ?? '',
      action: json['action'] as String? ?? '',
      riskLevel: json['riskLevel'] as String? ?? 'INTERNAL_WRITE',
      status: json['status'] as String? ?? 'PENDING',
      targetResource: json['targetResource'] as String?,
      impactSummary: json['impactSummary'] as String?,
      input: rawInput is Map
          ? rawInput.map((key, value) => MapEntry(key.toString(), value))
          : const {},
      note: json['note'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }

  AgentApproval toDomain() {
    return AgentApproval(
      id: id,
      runId: runId,
      toolKey: toolKey,
      action: action,
      riskLevel: riskLevel,
      status: AgentApprovalStatus.fromWire(status),
      targetResource: targetResource,
      impactSummary: impactSummary,
      input: input,
      note: note,
      createdAt: createdAt,
    );
  }
}
