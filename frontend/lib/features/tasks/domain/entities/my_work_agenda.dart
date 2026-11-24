import 'task_item.dart';

/// The backend's `/my-work` buckets, including execution and human review.
///
/// The split is computed server-side on purpose: "blocked" depends on the task's
/// own status while "awaiting others" depends on who owns it. Re-deriving that
/// from a flat task list on the client would silently disagree with the counts
/// the server reports.
enum MyWorkLane {
  actionable,
  running,
  waitingApproval,
  blocked,
  awaitingOthers,
  recentlyDone,
}

class MyWorkAgenda {
  const MyWorkAgenda({
    this.actionable = const [],
    this.blocked = const [],
    this.awaitingOthers = const [],
    this.recentlyDone = const [],
    this.running = const [],
    this.waitingApproval = const [],
  });

  const MyWorkAgenda.empty()
    : actionable = const [],
      blocked = const [],
      awaitingOthers = const [],
      recentlyDone = const [],
      running = const [],
      waitingApproval = const [];

  final List<TaskItem> actionable;
  final List<TaskItem> blocked;
  final List<TaskItem> awaitingOthers;
  final List<TaskItem> recentlyDone;
  final List<TaskItem> running;
  final List<TaskItem> waitingApproval;

  List<TaskItem> tasksFor(MyWorkLane lane) {
    return switch (lane) {
      MyWorkLane.actionable => actionable,
      MyWorkLane.blocked => blocked,
      MyWorkLane.awaitingOthers => awaitingOthers,
      MyWorkLane.recentlyDone => recentlyDone,
      MyWorkLane.running => running,
      MyWorkLane.waitingApproval => waitingApproval,
    };
  }

  int countFor(MyWorkLane lane) => tasksFor(lane).length;

  /// Open work only: the done lane is history, not a queue.
  int get openCount =>
      actionable.length +
      running.length +
      waitingApproval.length +
      blocked.length +
      awaitingOthers.length;

  bool get isEmpty => openCount == 0 && recentlyDone.isEmpty;

  Iterable<TaskItem> get allTasks sync* {
    yield* actionable;
    yield* running;
    yield* waitingApproval;
    yield* blocked;
    yield* awaitingOthers;
    yield* recentlyDone;
  }
}
