import '../entities/accounting_account.dart';
import '../entities/accounting_voucher.dart';
import '../entities/trial_balance_row.dart';

class CreateAccountingVoucherLineInput {
  const CreateAccountingVoucherLineInput({
    required this.accountId,
    required this.summary,
    required this.debitAmount,
    required this.creditAmount,
  });

  final String accountId;
  final String summary;
  final double debitAmount;
  final double creditAmount;
}

abstract class AccountingRepository {
  Future<List<AccountingAccount>> listAccounts(String workspaceId);

  Future<AccountingAccount> createAccount({
    required String workspaceId,
    required String code,
    required String name,
    required String category,
    required String normalBalance,
  });

  Future<List<AccountingVoucher>> listVouchers(String workspaceId);

  Future<AccountingVoucher> createVoucher({
    required String workspaceId,
    required String voucherDate,
    required String description,
    required List<CreateAccountingVoucherLineInput> lines,
  });

  Future<AccountingVoucher> postVoucher({
    required String workspaceId,
    required String voucherId,
  });

  Future<List<TrialBalanceRow>> trialBalance({
    required String workspaceId,
    String? period,
  });
}
