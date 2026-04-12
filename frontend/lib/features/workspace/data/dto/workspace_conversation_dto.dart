import '../../domain/entities/workspace_conversation.dart';

class WorkspaceConversationDto {
  const WorkspaceConversationDto({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.unreadCount,
    required this.available,
    required this.lastActivityAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final String kind;
  final int unreadCount;
  final bool available;
  final String? lastActivityAt;

  factory WorkspaceConversationDto.fromJson(Map<String, Object?> json) {
    return WorkspaceConversationDto(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      kind: json['kind'] as String,
      unreadCount: json['unreadCount'] as int,
      available: json['available'] as bool,
      lastActivityAt: json['lastActivityAt'] as String?,
    );
  }

  WorkspaceConversation toDomain() {
    return WorkspaceConversation(
      id: id,
      title: title,
      subtitle: subtitle,
      kind: kind,
      unreadCount: unreadCount,
      available: available,
      lastActivityAt: lastActivityAt,
    );
  }
}
