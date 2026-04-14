class WorkspaceMember {
  const WorkspaceMember({
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
}
