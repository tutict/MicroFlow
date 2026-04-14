class KnowledgeDocument {
  const KnowledgeDocument({
    required this.id,
    required this.workspaceId,
    required this.channelId,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.summary,
    required this.snippetCount,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String workspaceId;
  final String? channelId;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final String summary;
  final int snippetCount;
  final String status;
  final String createdAt;
}
