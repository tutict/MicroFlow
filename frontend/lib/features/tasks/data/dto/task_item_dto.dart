import '../../domain/entities/task_item.dart';

class TaskItemDto {
  const TaskItemDto({
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
  final String? dueAt;
  final String? createdAt;
  final String? updatedAt;
  final String? completedAt;

  factory TaskItemDto.fromJson(Map<String, Object?> json) {
    return TaskItemDto(
      id: json['id'] as String,
      workspaceId: json['workspaceId'] as String,
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'OPEN',
      priority: json['priority'] as String? ?? 'NORMAL',
      projectId: json['projectId'] as String?,
      projectName: json['projectName'] as String?,
      detail: json['detail'] as String?,
      assigneeUserId: json['assigneeUserId'] as String?,
      assigneeDisplayName: json['assigneeDisplayName'] as String?,
      creatorUserId: json['creatorUserId'] as String?,
      originChannelId: json['originChannelId'] as String?,
      originMessageId: json['originMessageId'] as String?,
      dueAt: json['dueAt'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      completedAt: json['completedAt'] as String?,
    );
  }

  TaskItem toDomain() {
    return TaskItem(
      id: id,
      workspaceId: workspaceId,
      title: title,
      status: status,
      priority: priority,
      projectId: projectId,
      projectName: projectName,
      detail: detail,
      assigneeUserId: assigneeUserId,
      assigneeDisplayName: assigneeDisplayName,
      creatorUserId: creatorUserId,
      originChannelId: originChannelId,
      originMessageId: originMessageId,
      dueAt: _parseInstant(dueAt),
      createdAt: _parseInstant(createdAt),
      updatedAt: _parseInstant(updatedAt),
      completedAt: _parseInstant(completedAt),
    );
  }

  static DateTime? _parseInstant(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal();
  }
}
