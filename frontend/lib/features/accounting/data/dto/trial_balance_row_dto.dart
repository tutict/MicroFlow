import '../../domain/entities/trial_balance_row.dart';

class TrialBalanceRowDto {
  const TrialBalanceRowDto({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.category,
    required this.normalBalance,
    required this.debitAmount,
    required this.creditAmount,
    required this.balanceAmount,
    required this.balanceDirection,
  });

  factory TrialBalanceRowDto.fromJson(Map<String, Object?> json) {
    return TrialBalanceRowDto(
      accountId: json['accountId'] as String? ?? '',
      accountCode: json['accountCode'] as String? ?? '',
      accountName: json['accountName'] as String? ?? '',
      category: json['category'] as String? ?? '',
      normalBalance: json['normalBalance'] as String? ?? '',
      debitAmount: _toDouble(json['debitAmount']),
      creditAmount: _toDouble(json['creditAmount']),
      balanceAmount: _toDouble(json['balanceAmount']),
      balanceDirection: json['balanceDirection'] as String? ?? '',
    );
  }

  final String accountId;
  final String accountCode;
  final String accountName;
  final String category;
  final String normalBalance;
  final double debitAmount;
  final double creditAmount;
  final double balanceAmount;
  final String balanceDirection;

  TrialBalanceRow toDomain() {
    return TrialBalanceRow(
      accountId: accountId,
      accountCode: accountCode,
      accountName: accountName,
      category: category,
      normalBalance: normalBalance,
      debitAmount: debitAmount,
      creditAmount: creditAmount,
      balanceAmount: balanceAmount,
      balanceDirection: balanceDirection,
    );
  }
}

double _toDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}
