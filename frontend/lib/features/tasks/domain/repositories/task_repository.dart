import '../../domain/entities/my_work_agenda.dart';
import '../../domain/entities/task_activity.dart';
import '../../domain/entities/task_item.dart';
import '../../domain/entities/task_project.dart';
import '../../domain/entities/task_summary.dart';

abstract class TaskRepository {
  const TaskRepository();

  Future<List<TaskProject>> listProjects(String workspaceId);

  Future<TaskProject> createProject({
    required String workspaceId,
    required String name,
    String? description,
  });

  Future<List<TaskItem>> listTasks({
    required String workspaceId,
    String? projectId,
    String? status,
    String? assignee,
    bool mine = false,
  });

  Future<TaskItem> createTask({
    required String workspaceId,
    required String title,
    String? projectId,
    String? detail,
    String? priority,
    String? status,
    String? assigneeUserId,
    bool assigneeIsSelf = false,
    String? originChannelId,
    String? originMessageId,
    DateTime? dueAt,
  });

  Future<TaskItem> updateStatus({
    required String workspaceId,
    required String taskId,
    required String status,
  });

  Future<TaskItem> assign({
    required String workspaceId,
    required String taskId,
    String? assigneeUserId,
    bool assigneeIsSelf = false,
  });

  Future<List<TaskActivity>> listActivity({
    required String workspaceId,
    required String taskId,
  });

  Future<TaskSummary> summarize({
    required String workspaceId,
    String? projectId,
  });

  /// "My work" aggregation: the tasks assigned to the caller, bucketed by what
  /// the caller can act on. Deliberately separate from [listTasks] — the agenda
  /// is a queue, and the queue order is the server's business.
  Future<MyWorkAgenda> myWork({
    required String workspaceId,
    int limit = 50,
  });
}
