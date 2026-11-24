import '../../domain/entities/my_work_agenda.dart';
import '../../domain/entities/task_item.dart';
import 'task_item_dto.dart';

class MyWorkAgendaDto {
  const MyWorkAgendaDto({
    this.actionable = const [],
    this.blocked = const [],
    this.awaitingOthers = const [],
    this.recentlyDone = const [],
    this.running = const [],
    this.waitingApproval = const [],
  });

  final List<TaskItemDto> actionable;
  final List<TaskItemDto> blocked;
  final List<TaskItemDto> awaitingOthers;
  final List<TaskItemDto> recentlyDone;
  final List<TaskItemDto> running;
  final List<TaskItemDto> waitingApproval;

  factory MyWorkAgendaDto.fromJson(Map<String, Object?> json) {
    return MyWorkAgendaDto(
      actionable: _tasks(json['actionable']),
      blocked: _tasks(json['blocked']),
      awaitingOthers: _tasks(json['awaitingOthers']),
      recentlyDone: _tasks(json['recentlyDone']),
      running: _tasks(json['running']),
      waitingApproval: _tasks(json['waitingApproval']),
    );
  }

  /// A malformed lane degrades to empty rather than failing the whole agenda:
  /// one bad bucket must not hide the work the server did parse.
  static List<TaskItemDto> _tasks(Object? value) {
    if (value is! List) {
      return const [];
    }
    return [
      for (final item in value)
        if (item is Map) TaskItemDto.fromJson(Map<String, Object?>.from(item)),
    ];
  }

  MyWorkAgenda toDomain() {
    return MyWorkAgenda(
      actionable: _toDomain(actionable),
      blocked: _toDomain(blocked),
      awaitingOthers: _toDomain(awaitingOthers),
      recentlyDone: _toDomain(recentlyDone),
      running: _toDomain(running),
      waitingApproval: _toDomain(waitingApproval),
    );
  }

  static List<TaskItem> _toDomain(List<TaskItemDto> tasks) {
    return [for (final task in tasks) task.toDomain()];
  }
}
