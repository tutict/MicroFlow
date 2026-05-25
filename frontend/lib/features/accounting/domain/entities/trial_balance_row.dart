class TrialBalanceRow {
  const TrialBalanceRow({
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

  final String accountId;
  final String accountCode;
  final String accountName;
  final String category;
  final String normalBalance;
  final double debitAmount;
  final double creditAmount;
  final double balanceAmount;
  final String balanceDirection;
}
