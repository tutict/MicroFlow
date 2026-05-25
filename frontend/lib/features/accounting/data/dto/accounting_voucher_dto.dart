import '../../domain/entities/accounting_voucher.dart';
import '../../domain/entities/accounting_voucher_line.dart';

class AccountingVoucherDto {
  const AccountingVoucherDto({
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

  factory AccountingVoucherDto.fromJson(Map<String, Object?> json) {
    final rawLines = json['lines'];
    return AccountingVoucherDto(
      id: json['id'] as String? ?? '',
      workspaceId: json['workspaceId'] as String? ?? '',
      voucherNo: json['voucherNo'] as String? ?? '',
      voucherDate: json['voucherDate'] as String? ?? '',
      period: json['period'] as String? ?? '',
      status: json['status'] as String? ?? '',
      description: json['description'] as String? ?? '',
      totalDebit: _toDouble(json['totalDebit']),
      totalCredit: _toDouble(json['totalCredit']),
      createdByUserId: json['createdByUserId'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      postedAt: json['postedAt'] as String?,
      lines: rawLines is List
          ? rawLines
                .cast<Map>()
                .map(
                  (line) => AccountingVoucherLineDto.fromJson(
                    line.cast<String, Object?>(),
                  ),
                )
                .toList()
          : const [],
    );
  }

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
  final List<AccountingVoucherLineDto> lines;

  AccountingVoucher toDomain() {
    return AccountingVoucher(
      id: id,
      workspaceId: workspaceId,
      voucherNo: voucherNo,
      voucherDate: voucherDate,
      period: period,
      status: status,
      description: description,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      createdByUserId: createdByUserId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      postedAt: postedAt,
      lines: lines.map((line) => line.toDomain()).toList(),
    );
  }
}

class AccountingVoucherLineDto {
  const AccountingVoucherLineDto({
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

  factory AccountingVoucherLineDto.fromJson(Map<String, Object?> json) {
    return AccountingVoucherLineDto(
      id: json['id'] as String? ?? '',
      voucherId: json['voucherId'] as String? ?? '',
      lineNo: (json['lineNo'] as num?)?.toInt() ?? 0,
      accountId: json['accountId'] as String? ?? '',
      accountCode: json['accountCode'] as String? ?? '',
      accountName: json['accountName'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      debitAmount: _toDouble(json['debitAmount']),
      creditAmount: _toDouble(json['creditAmount']),
    );
  }

  final String id;
  final String voucherId;
  final int lineNo;
  final String accountId;
  final String accountCode;
  final String accountName;
  final String summary;
  final double debitAmount;
  final double creditAmount;

  AccountingVoucherLine toDomain() {
    return AccountingVoucherLine(
      id: id,
      voucherId: voucherId,
      lineNo: lineNo,
      accountId: accountId,
      accountCode: accountCode,
      accountName: accountName,
      summary: summary,
      debitAmount: debitAmount,
      creditAmount: creditAmount,
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
