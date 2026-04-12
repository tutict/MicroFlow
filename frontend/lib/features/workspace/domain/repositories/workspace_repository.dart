import '../../../chat/domain/entities/channel_summary.dart';
import '../entities/workspace_conversation.dart';
import '../entities/workspace_summary.dart';

abstract interface class WorkspaceRepository {
  Future<List<WorkspaceSummary>> listWorkspaces();

  Future<List<ChannelSummary>> listChannels(String workspaceId);

  Future<List<WorkspaceConversation>> listConversations(String workspaceId);
}
