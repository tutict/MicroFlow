import '../../domain/entities/task_summary.dart';

class TaskSummaryDto {
  const TaskSummaryDto({
    required this.total,
    required this.open,
    required this.inProgress,
    required this.blocked,
    required this.done,
  });

  final int total;
  final int open;
  final int inProgress;
  final int blocked;
  final int done;

  factory TaskSummaryDto.fromJson(Map<String, Object?> json) {
    return TaskSummaryDto(
      total: (json['total'] as num?)?.toInt() ?? 0,
      open: (json['open'] as num?)?.toInt() ?? 0,
      inProgress: (json['inProgress'] as num?)?.toInt() ?? 0,
      blocked: (json['blocked'] as num?)?.toInt() ?? 0,
      done: (json['done'] as num?)?.toInt() ?? 0,
    );
  }

  TaskSummary toDomain() {
    return TaskSummary(
      total: total,
      open: open,
      inProgress: inProgress,
      blocked: blocked,
      done: done,
    );
  }
}
