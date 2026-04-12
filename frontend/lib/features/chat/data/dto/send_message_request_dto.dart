class SendMessageRequestDto {
  const SendMessageRequestDto({
    required this.workspaceId,
    required this.content,
  });

  final String workspaceId;
  final String content;

  Map<String, Object?> toJson() {
    return {
      'workspaceId': workspaceId,
      'content': content,
    };
  }
}
