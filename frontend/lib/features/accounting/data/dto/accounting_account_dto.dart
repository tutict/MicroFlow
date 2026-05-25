import '../../domain/entities/accounting_account.dart';

class AccountingAccountDto {
  const AccountingAccountDto({
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

  factory AccountingAccountDto.fromJson(Map<String, Object?> json) {
    return AccountingAccountDto(
      id: json['id'] as String? ?? '',
      workspaceId: json['workspaceId'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      normalBalance: json['normalBalance'] as String? ?? '',
      active: json['active'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  final String id;
  final String workspaceId;
  final String code;
  final String name;
  final String category;
  final String normalBalance;
  final bool active;
  final String createdAt;
  final String updatedAt;

  AccountingAccount toDomain() {
    return AccountingAccount(
      id: id,
      workspaceId: workspaceId,
      code: code,
      name: name,
      category: category,
      normalBalance: normalBalance,
      active: active,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
