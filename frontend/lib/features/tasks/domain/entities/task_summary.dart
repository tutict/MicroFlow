class TaskSummary {
  const TaskSummary({
    required this.total,
    required this.open,
    required this.inProgress,
    required this.blocked,
    required this.done,
  });

  const TaskSummary.empty()
      : total = 0,
        open = 0,
        inProgress = 0,
        blocked = 0,
        done = 0;

  final int total;
  final int open;
  final int inProgress;
  final int blocked;
  final int done;
}
