import '../../domain/entities/task_project.dart';

class TaskProjectDto {
  const TaskProjectDto({
    required this.id,
    required this.name,
    required this.status,
    required this.taskCount,
    required this.openTaskCount,
    this.description,
  });

  final String id;
  final String name;
  final String status;
  final int taskCount;
  final int openTaskCount;
  final String? description;

  factory TaskProjectDto.fromJson(Map<String, Object?> json) {
    return TaskProjectDto(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'ACTIVE',
      taskCount: (json['taskCount'] as num?)?.toInt() ?? 0,
      openTaskCount: (json['openTaskCount'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
    );
  }

  TaskProject toDomain() {
    return TaskProject(
      id: id,
      name: name,
      status: status,
      taskCount: taskCount,
      openTaskCount: openTaskCount,
      description: description,
    );
  }
}
