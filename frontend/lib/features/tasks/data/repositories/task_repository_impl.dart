import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/rest_client.dart';
import '../../domain/entities/my_work_agenda.dart';
import '../../domain/entities/task_activity.dart';
import '../../domain/entities/task_item.dart';
import '../../domain/entities/task_project.dart';
import '../../domain/entities/task_summary.dart';
import '../../domain/repositories/task_repository.dart';
import '../dto/my_work_agenda_dto.dart';
import '../dto/task_activity_dto.dart';
import '../dto/task_item_dto.dart';
import '../dto/task_project_dto.dart';
import '../dto/task_summary_dto.dart';

class TaskRepositoryImpl implements TaskRepository {
  const TaskRepositoryImpl(this._restClient);

  final RestClient _restClient;

  @override
  Future<List<TaskProject>> listProjects(String workspaceId) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.workspaceTaskProjects(workspaceId),
    );
    return response
        .map((json) => TaskProjectDto.fromJson(json).toDomain())
        .toList();
  }

  @override
  Future<TaskProject> createProject({
    required String workspaceId,
    required String name,
    String? description,
  }) async {
    final response = await _restClient.postJson(
      ApiEndpoints.workspaceTaskProjects(workspaceId),
      body: {
        'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    return TaskProjectDto.fromJson(response).toDomain();
  }

  @override
  Future<List<TaskItem>> listTasks({
    required String workspaceId,
    String? projectId,
    String? status,
    String? assignee,
    bool mine = false,
  }) async {
    final query = <String, String>{
      if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      if (status != null && status.isNotEmpty) 'status': status,
      if (assignee != null && assignee.isNotEmpty) 'assignee': assignee,
      if (mine) 'mine': 'true',
    };
    final response = await _restClient.getJsonList(
      ApiEndpoints.workspaceTasks(workspaceId),
      queryParameters: query.isEmpty ? null : query,
    );
    return response
        .map((json) => TaskItemDto.fromJson(json).toDomain())
        .toList();
  }

  @override
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
  }) async {
    final response = await _restClient.postJson(
      ApiEndpoints.workspaceTasks(workspaceId),
      body: {
        'title': title,
        if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
        if (detail != null && detail.isNotEmpty) 'detail': detail,
        if (priority != null && priority.isNotEmpty) 'priority': priority,
        if (status != null && status.isNotEmpty) 'status': status,
        if (assigneeUserId != null && assigneeUserId.isNotEmpty)
          'assigneeUserId': assigneeUserId,
        if (assigneeIsSelf) 'assigneeIsSelf': true,
        if (originChannelId != null && originChannelId.isNotEmpty)
          'originChannelId': originChannelId,
        if (originMessageId != null && originMessageId.isNotEmpty)
          'originMessageId': originMessageId,
        if (dueAt != null) 'dueAt': dueAt.toUtc().toIso8601String(),
      },
    );
    return TaskItemDto.fromJson(response).toDomain();
  }

  @override
  Future<TaskItem> updateStatus({
    required String workspaceId,
    required String taskId,
    required String status,
  }) async {
    final response = await _restClient.putJson(
      ApiEndpoints.workspaceTaskStatus(workspaceId, taskId),
      body: {'status': status},
    );
    return TaskItemDto.fromJson(response).toDomain();
  }

  @override
  Future<TaskItem> assign({
    required String workspaceId,
    required String taskId,
    String? assigneeUserId,
    bool assigneeIsSelf = false,
  }) async {
    final response = await _restClient.putJson(
      ApiEndpoints.workspaceTaskAssignee(workspaceId, taskId),
      body: {
        if (assigneeUserId != null && assigneeUserId.isNotEmpty)
          'assigneeUserId': assigneeUserId,
        if (assigneeIsSelf) 'assigneeIsSelf': true,
      },
    );
    return TaskItemDto.fromJson(response).toDomain();
  }

  @override
  Future<List<TaskActivity>> listActivity({
    required String workspaceId,
    required String taskId,
  }) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.workspaceTaskActivity(workspaceId, taskId),
    );
    return response
        .map((json) => TaskActivityDto.fromJson(json).toDomain())
        .toList();
  }

  @override
  Future<TaskSummary> summarize({
    required String workspaceId,
    String? projectId,
  }) async {
    final response = await _restClient.getJson(
      ApiEndpoints.workspaceTaskSummary(workspaceId),
      queryParameters: projectId == null || projectId.isEmpty
          ? null
          : <String, String>{'projectId': projectId},
    );
    return TaskSummaryDto.fromJson(response).toDomain();
  }

  @override
  Future<MyWorkAgenda> myWork({
    required String workspaceId,
    int limit = 50,
  }) async {
    final response = await _restClient.getJson(
      ApiEndpoints.workspaceMyWork(workspaceId),
      queryParameters: <String, String>{'limit': '$limit'},
    );
    return MyWorkAgendaDto.fromJson(response).toDomain();
  }
}
