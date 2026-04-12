import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/rest_client.dart';
import '../../../chat/data/dto/channel_summary_dto.dart';
import '../../../chat/domain/entities/channel_summary.dart';
import '../dto/workspace_conversation_dto.dart';
import '../../domain/entities/workspace_conversation.dart';
import '../dto/workspace_summary_dto.dart';
import '../../domain/entities/workspace_summary.dart';
import '../../domain/repositories/workspace_repository.dart';

class WorkspaceRepositoryImpl implements WorkspaceRepository {
  const WorkspaceRepositoryImpl(this._restClient);

  final RestClient _restClient;

  @override
  Future<List<WorkspaceSummary>> listWorkspaces() async {
    final response = await _restClient.getJsonList(ApiEndpoints.workspaces);
    return response.map((json) => WorkspaceSummaryDto.fromJson(json).toDomain()).toList();
  }

  @override
  Future<List<ChannelSummary>> listChannels(String workspaceId) async {
    final response = await _restClient.getJsonList(ApiEndpoints.workspaceChannels(workspaceId));
    return response.map((json) => ChannelSummaryDto.fromJson(json).toDomain()).toList();
  }

  @override
  Future<List<WorkspaceConversation>> listConversations(String workspaceId) async {
    final response = await _restClient.getJsonList(ApiEndpoints.workspaceConversations(workspaceId));
    return response.map((json) => WorkspaceConversationDto.fromJson(json).toDomain()).toList();
  }
}
