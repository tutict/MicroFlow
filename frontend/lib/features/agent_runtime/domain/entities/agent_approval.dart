enum AgentApprovalStatus {
  pending,
  approved,
  rejected,
  cancelled;

  static AgentApprovalStatus fromWire(String? value) {
    return switch (value) {
      'APPROVED' => AgentApprovalStatus.approved,
      'REJECTED' => AgentApprovalStatus.rejected,
      'CANCELLED' => AgentApprovalStatus.cancelled,
      _ => AgentApprovalStatus.pending,
    };
  }
}

class AgentApproval {
  const AgentApproval({
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
  final AgentApprovalStatus status;
  final String? targetResource;
  final String? impactSummary;
  final Map<String, Object?> input;
  final String? note;
  final String? createdAt;

  bool get isPending => status == AgentApprovalStatus.pending;
}
