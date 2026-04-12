import '../../domain/entities/chat_message.dart';

class MessageDto {
  const MessageDto({
    required this.id,
    required this.workspaceId,
    required this.channelId,
    required this.senderUserId,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String workspaceId;
  final String channelId;
  final String senderUserId;
  final String content;
  final String createdAt;

  factory MessageDto.fromJson(Map<String, Object?> json) {
    return MessageDto(
      id: json['id'] as String,
      workspaceId: json['workspaceId'] as String,
      channelId: json['channelId'] as String,
      senderUserId: json['senderUserId'] as String,
      content: json['content'] as String,
      createdAt: json['createdAt'] as String,
    );
  }

  ChatMessage toDomain() {
    return ChatMessage(
      id: id,
      author: senderUserId,
      text: content,
      createdAt: createdAt,
      isAgent: senderUserId.startsWith('agent:'),
    );
  }
}
