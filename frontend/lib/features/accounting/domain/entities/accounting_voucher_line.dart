class AccountingVoucherLine {
  const AccountingVoucherLine({
    required this.id,
    required this.voucherId,
    required this.lineNo,
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.summary,
    required this.debitAmount,
    required this.creditAmount,
  });

  final String id;
  final String voucherId;
  final int lineNo;
  final String accountId;
  final String accountCode;
  final String accountName;
  final String summary;
  final double debitAmount;
  final double creditAmount;
}
