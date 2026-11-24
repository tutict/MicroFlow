class TaskProject {
  const TaskProject({
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
}
