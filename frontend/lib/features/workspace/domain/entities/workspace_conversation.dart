class WorkspaceConversation {
  const WorkspaceConversation({
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

  WorkspaceConversation copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? kind,
    int? unreadCount,
    bool? available,
    String? lastActivityAt,
  }) {
    return WorkspaceConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      kind: kind ?? this.kind,
      unreadCount: unreadCount ?? this.unreadCount,
      available: available ?? this.available,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    );
  }
}
