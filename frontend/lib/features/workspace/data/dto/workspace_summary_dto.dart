import '../../domain/entities/workspace_summary.dart';

class WorkspaceSummaryDto {
  const WorkspaceSummaryDto({
    required this.id,
    required this.name,
    required this.memberCount,
  });

  final String id;
  final String name;
  final int memberCount;

  factory WorkspaceSummaryDto.fromJson(Map<String, Object?> json) {
    return WorkspaceSummaryDto(
      id: json['id'] as String,
      name: json['name'] as String,
      memberCount: json['memberCount'] as int,
    );
  }

  WorkspaceSummary toDomain() {
    return WorkspaceSummary(
      id: id,
      name: name,
      memberCount: memberCount,
    );
  }
}
