class TaskItem {
  const TaskItem({
    required this.id,
    required this.workspaceId,
    required this.title,
    required this.status,
    required this.priority,
    this.projectId,
    this.projectName,
    this.detail,
    this.assigneeUserId,
    this.assigneeDisplayName,
    this.creatorUserId,
    this.originChannelId,
    this.originMessageId,
    this.dueAt,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String workspaceId;
  final String title;
  final String status;
  final String priority;
  final String? projectId;
  final String? projectName;
  final String? detail;
  final String? assigneeUserId;
  final String? assigneeDisplayName;
  final String? creatorUserId;
  final String? originChannelId;
  final String? originMessageId;
  final DateTime? dueAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  bool get isDone => status == 'DONE';

  bool get isOverdue {
    final due = dueAt;
    if (due == null || isDone) {
      return false;
    }
    return due.isBefore(DateTime.now());
  }

  bool get isUnassigned => assigneeUserId == null || assigneeUserId!.isEmpty;
}
