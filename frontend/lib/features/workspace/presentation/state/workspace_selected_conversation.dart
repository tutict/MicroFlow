enum WorkspaceSelectedConversationKind {
  channel,
  directMessage,
  agentThread,
}

class WorkspaceSelectedConversation {
  const WorkspaceSelectedConversation({
    required this.id,
    required this.title,
    required this.kind,
    this.isAvailable = true,
  });

  final String id;
  final String title;
  final WorkspaceSelectedConversationKind kind;
  final bool isAvailable;

  bool get isChannel => kind == WorkspaceSelectedConversationKind.channel;

  bool get isChannelBacked =>
      kind == WorkspaceSelectedConversationKind.channel ||
      (kind == WorkspaceSelectedConversationKind.directMessage && isAvailable) ||
      (kind == WorkspaceSelectedConversationKind.agentThread && isAvailable);

  WorkspaceSelectedConversation copyWith({
    String? id,
    String? title,
    WorkspaceSelectedConversationKind? kind,
    bool? isAvailable,
  }) {
    return WorkspaceSelectedConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}
