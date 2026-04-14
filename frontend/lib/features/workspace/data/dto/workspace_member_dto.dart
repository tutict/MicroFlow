import '../../domain/entities/workspace_member.dart';

class WorkspaceMemberDto {
  const WorkspaceMemberDto({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  final String userId;
  final String email;
  final String displayName;
  final String role;
  final String joinedAt;

  factory WorkspaceMemberDto.fromJson(Map<String, Object?> json) {
    return WorkspaceMemberDto(
      userId: json['userId'] as String,
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      role: json['role'] as String? ?? 'MEMBER',
      joinedAt: json['joinedAt'] as String? ?? '',
    );
  }

  WorkspaceMember toDomain() {
    return WorkspaceMember(
      userId: userId,
      email: email,
      displayName: displayName,
      role: role,
      joinedAt: joinedAt,
    );
  }
}
