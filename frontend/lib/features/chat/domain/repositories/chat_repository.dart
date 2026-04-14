import '../entities/collaboration_event.dart';
import '../entities/collaboration_run.dart';
import '../entities/chat_message.dart';

abstract interface class ChatRepository {
  Future<List<ChatMessage>> listMessages(String channelId);

  Future<List<CollaborationEvent>> listCollaborationHistory(String channelId);

  Future<List<CollaborationRun>> listCollaborationRuns(String channelId);

  Future<ChatMessage> sendMessage({
    required String workspaceId,
    required String channelId,
    required String senderUserId,
    required String content,
  });
}
