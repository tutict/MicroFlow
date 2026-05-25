import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/rest_client.dart';
import '../../domain/entities/accounting_account.dart';
import '../../domain/entities/accounting_voucher.dart';
import '../../domain/entities/trial_balance_row.dart';
import '../../domain/repositories/accounting_repository.dart';
import '../dto/accounting_account_dto.dart';
import '../dto/accounting_voucher_dto.dart';
import '../dto/trial_balance_row_dto.dart';

class AccountingRepositoryImpl implements AccountingRepository {
  const AccountingRepositoryImpl(this._restClient);

  final RestClient _restClient;

  @override
  Future<List<AccountingAccount>> listAccounts(String workspaceId) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.workspaceAccountingAccounts(workspaceId),
    );
    return response
        .map((json) => AccountingAccountDto.fromJson(json).toDomain())
        .toList();
  }

  @override
  Future<AccountingAccount> createAccount({
    required String workspaceId,
    required String code,
    required String name,
    required String category,
    required String normalBalance,
  }) async {
    final response = await _restClient.postJson(
      ApiEndpoints.workspaceAccountingAccounts(workspaceId),
      body: {
        'code': code,
        'name': name,
        'category': category,
        'normalBalance': normalBalance,
      },
    );
    return AccountingAccountDto.fromJson(response).toDomain();
  }

  @override
  Future<List<AccountingVoucher>> listVouchers(String workspaceId) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.workspaceAccountingVouchers(workspaceId),
    );
    return response
        .map((json) => AccountingVoucherDto.fromJson(json).toDomain())
        .toList();
  }

  @override
  Future<AccountingVoucher> createVoucher({
    required String workspaceId,
    required String voucherDate,
    required String description,
    required List<CreateAccountingVoucherLineInput> lines,
  }) async {
    final response = await _restClient.postJson(
      ApiEndpoints.workspaceAccountingVouchers(workspaceId),
      body: {
        'voucherDate': voucherDate,
        'description': description,
        'lines': lines
            .map(
              (line) => {
                'accountId': line.accountId,
                'summary': line.summary,
                'debitAmount': line.debitAmount,
                'creditAmount': line.creditAmount,
              },
            )
            .toList(),
      },
    );
    return AccountingVoucherDto.fromJson(response).toDomain();
  }

  @override
  Future<AccountingVoucher> postVoucher({
    required String workspaceId,
    required String voucherId,
  }) async {
    final response = await _restClient.postJson(
      ApiEndpoints.workspaceAccountingVoucherPost(workspaceId, voucherId),
      body: const {},
    );
    return AccountingVoucherDto.fromJson(response).toDomain();
  }

  @override
  Future<List<TrialBalanceRow>> trialBalance({
    required String workspaceId,
    String? period,
  }) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.workspaceAccountingTrialBalance(workspaceId),
      queryParameters: period == null || period.isEmpty
          ? null
          : {'period': period},
    );
    return response
        .map((json) => TrialBalanceRowDto.fromJson(json).toDomain())
        .toList();
  }
}
