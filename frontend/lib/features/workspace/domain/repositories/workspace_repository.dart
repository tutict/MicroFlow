import 'dart:typed_data';

import '../../../chat/domain/entities/channel_summary.dart';
import '../entities/knowledge_document.dart';
import '../entities/workspace_member.dart';
import '../entities/workspace_conversation.dart';
import '../entities/workspace_summary.dart';

abstract interface class WorkspaceRepository {
  Future<List<WorkspaceSummary>> listWorkspaces();

  Future<WorkspaceSummary> createWorkspace(String name);

  Future<List<ChannelSummary>> listChannels(String workspaceId);

  Future<List<WorkspaceConversation>> listConversations(String workspaceId);

  Future<List<WorkspaceMember>> listMembers(String workspaceId);

  Future<List<WorkspaceMember>> addMemberByEmail({
    required String workspaceId,
    required String email,
  });

  Future<List<KnowledgeDocument>> listKnowledgeDocuments(String workspaceId);

  Future<KnowledgeDocument> uploadKnowledgeDocument({
    required String workspaceId,
    required String fileName,
    required Uint8List bytes,
    String? channelId,
  });
}
