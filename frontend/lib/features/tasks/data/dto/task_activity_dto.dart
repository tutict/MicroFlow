import '../../domain/entities/task_activity.dart';

class TaskActivityDto {
  const TaskActivityDto({
    required this.id,
    required this.eventType,
    required this.createdAt,
    this.actorDisplayName,
    this.fromValue,
    this.toValue,
    this.note,
  });

  final String id;
  final String eventType;
  final String? createdAt;
  final String? actorDisplayName;
  final String? fromValue;
  final String? toValue;
  final String? note;

  factory TaskActivityDto.fromJson(Map<String, Object?> json) {
    return TaskActivityDto(
      id: json['id'] as String,
      eventType: json['eventType'] as String? ?? '',
      createdAt: json['createdAt'] as String?,
      actorDisplayName: json['actorDisplayName'] as String?,
      fromValue: json['fromValue'] as String?,
      toValue: json['toValue'] as String?,
      note: json['note'] as String?,
    );
  }

  TaskActivity toDomain() {
    return TaskActivity(
      id: id,
      eventType: eventType,
      createdAt: DateTime.tryParse(createdAt ?? '')?.toLocal() ?? DateTime.now(),
      actorDisplayName: actorDisplayName,
      fromValue: fromValue,
      toValue: toValue,
      note: note,
    );
  }
}
