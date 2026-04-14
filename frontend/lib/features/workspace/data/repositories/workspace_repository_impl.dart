import 'dart:typed_data';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/rest_client.dart';
import '../../../chat/data/dto/channel_summary_dto.dart';
import '../../../chat/domain/entities/channel_summary.dart';
import '../dto/knowledge_document_dto.dart';
import '../dto/workspace_member_dto.dart';
import '../../domain/entities/knowledge_document.dart';
import '../../domain/entities/workspace_member.dart';
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
    return response
        .map((json) => WorkspaceSummaryDto.fromJson(json).toDomain())
        .toList();
  }

  @override
  Future<WorkspaceSummary> createWorkspace(String name) async {
    final response = await _restClient.postJson(
      ApiEndpoints.workspaces,
      body: {'name': name},
    );
    return WorkspaceSummaryDto.fromJson(response).toDomain();
  }

  @override
  Future<List<ChannelSummary>> listChannels(String workspaceId) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.workspaceChannels(workspaceId),
    );
    return response
        .map((json) => ChannelSummaryDto.fromJson(json).toDomain())
        .toList();
  }

  @override
  Future<List<WorkspaceConversation>> listConversations(
    String workspaceId,
  ) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.workspaceConversations(workspaceId),
    );
    return response
        .map((json) => WorkspaceConversationDto.fromJson(json).toDomain())
        .toList();
  }

  @override
  Future<List<WorkspaceMember>> listMembers(String workspaceId) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.workspaceMembers(workspaceId),
    );
    return response
        .map((json) => WorkspaceMemberDto.fromJson(json).toDomain())
        .toList();
  }

  @override
  Future<List<WorkspaceMember>> addMemberByEmail({
    required String workspaceId,
    required String email,
  }) async {
    final response = await _restClient.postJsonList(
      ApiEndpoints.workspaceMembers(workspaceId),
      body: {'email': email},
    );
    return response
        .map((json) => WorkspaceMemberDto.fromJson(json).toDomain())
        .toList();
  }

  @override
  Future<List<KnowledgeDocument>> listKnowledgeDocuments(
    String workspaceId,
  ) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.workspaceKnowledgeDocuments(workspaceId),
    );
    return response
        .map((json) => KnowledgeDocumentDto.fromJson(json).toDomain())
        .toList();
  }

  @override
  Future<KnowledgeDocument> uploadKnowledgeDocument({
    required String workspaceId,
    required String fileName,
    required Uint8List bytes,
    String? channelId,
  }) async {
    final response = await _restClient.postMultipart(
      ApiEndpoints.workspaceKnowledgeDocuments(workspaceId),
      fileField: 'file',
      fileName: fileName,
      fileBytes: bytes,
      fields: channelId == null || channelId.isEmpty
          ? null
          : {'channelId': channelId},
    );
    return KnowledgeDocumentDto.fromJson(response).toDomain();
  }
}
