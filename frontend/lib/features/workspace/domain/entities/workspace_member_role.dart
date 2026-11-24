/// Workspace member roles, mirroring the backend `WorkspaceRole` enum.
///
/// The order runs from most to least privileged so a role picker can render the
/// list without re-sorting, and [fromStored] tolerates the legacy `MEMBER`
/// value that older rows still carry.
enum WorkspaceMemberRole {
  owner('OWNER'),
  maintainer('MAINTAINER'),
  operator('OPERATOR'),
  viewer('VIEWER');

  const WorkspaceMemberRole(this.storedValue);

  final String storedValue;

  /// Whether this role may change another member's role.
  bool get canManageRoles => this == WorkspaceMemberRole.owner;
  static WorkspaceMemberRole fromStored(String? value) {
    if (value == null || value.isEmpty) {
      return WorkspaceMemberRole.operator;
    }
    final normalized = value.trim().toUpperCase();
    for (final role in WorkspaceMemberRole.values) {
      if (role.storedValue == normalized) {
        return role;
      }
    }
    return WorkspaceMemberRole.operator;
  }
}
