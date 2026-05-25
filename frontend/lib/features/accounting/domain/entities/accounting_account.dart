class AccountingAccount {
  const AccountingAccount({
    required this.id,
    required this.workspaceId,
    required this.code,
    required this.name,
    required this.category,
    required this.normalBalance,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String workspaceId;
  final String code;
  final String name;
  final String category;
  final String normalBalance;
  final bool active;
  final String createdAt;
  final String updatedAt;
}
