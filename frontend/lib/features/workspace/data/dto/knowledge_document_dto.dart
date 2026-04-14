import '../../domain/entities/knowledge_document.dart';

class KnowledgeDocumentDto {
  const KnowledgeDocumentDto({
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

  factory KnowledgeDocumentDto.fromJson(Map<String, Object?> json) {
    return KnowledgeDocumentDto(
      id: json['id'] as String,
      workspaceId: json['workspaceId'] as String,
      channelId: json['channelId'] as String?,
      fileName: json['fileName'] as String,
      contentType: json['contentType'] as String? ?? 'application/octet-stream',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      summary: json['summary'] as String? ?? '',
      snippetCount: (json['snippetCount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'READY',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  KnowledgeDocument toDomain() {
    return KnowledgeDocument(
      id: id,
      workspaceId: workspaceId,
      channelId: channelId,
      fileName: fileName,
      contentType: contentType,
      sizeBytes: sizeBytes,
      summary: summary,
      snippetCount: snippetCount,
      status: status,
      createdAt: createdAt,
    );
  }
}
