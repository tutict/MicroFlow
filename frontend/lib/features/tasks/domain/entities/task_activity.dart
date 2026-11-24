class TaskActivity {
  const TaskActivity({
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
  final DateTime createdAt;
  final String? actorDisplayName;
  final String? fromValue;
  final String? toValue;
  final String? note;
}
