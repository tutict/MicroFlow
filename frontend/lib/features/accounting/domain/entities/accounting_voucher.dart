import 'accounting_voucher_line.dart';

class AccountingVoucher {
  const AccountingVoucher({
    required this.id,
    required this.workspaceId,
    required this.voucherNo,
    required this.voucherDate,
    required this.period,
    required this.status,
    required this.description,
    required this.totalDebit,
    required this.totalCredit,
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
    required this.lines,
    this.postedAt,
  });

  final String id;
  final String workspaceId;
  final String voucherNo;
  final String voucherDate;
  final String period;
  final String status;
  final String description;
  final double totalDebit;
  final double totalCredit;
  final String createdByUserId;
  final String createdAt;
  final String updatedAt;
  final String? postedAt;
  final List<AccountingVoucherLine> lines;

  bool get isDraft => status == 'DRAFT';
}
