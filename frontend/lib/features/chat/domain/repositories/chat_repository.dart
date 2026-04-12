import '../entities/chat_message.dart';

abstract interface class ChatRepository {
  Future<List<ChatMessage>> listMessages(String channelId);

  Future<ChatMessage> sendMessage({
    required String workspaceId,
    required String channelId,
    required String senderUserId,
    required String content,
  });
}
