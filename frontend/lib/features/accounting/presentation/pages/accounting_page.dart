import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/accounting_account.dart';
import '../../domain/entities/accounting_voucher.dart';
import '../../domain/entities/accounting_voucher_line.dart';
import '../../domain/entities/trial_balance_row.dart';
import '../../domain/repositories/accounting_repository.dart';

typedef _AccountingDashboardQuery = ({String workspaceId, String period});

final _accountingDashboardProvider = FutureProvider.family
    .autoDispose<AccountingDashboard, _AccountingDashboardQuery>((
      ref,
      query,
    ) async {
      final repository = ref.watch(accountingRepositoryProvider);
      final accounts = await repository.listAccounts(query.workspaceId);
      final vouchers = await repository.listVouchers(query.workspaceId);
      final trialBalance = await repository.trialBalance(
        workspaceId: query.workspaceId,
        period: query.period,
      );
      return AccountingDashboard(
        accounts: accounts,
        vouchers: vouchers,
        trialBalance: trialBalance,
      );
    });

class AccountingDashboard {
  const AccountingDashboard({
    required this.accounts,
    required this.vouchers,
    required this.trialBalance,
  });

  final List<AccountingAccount> accounts;
  final List<AccountingVoucher> vouchers;
  final List<TrialBalanceRow> trialBalance;

  int get postedVoucherCount =>
      vouchers.where((voucher) => voucher.status == 'POSTED').length;

  double get periodDebitTotal =>
      trialBalance.fold(0, (sum, row) => sum + row.debitAmount);

  double get periodCreditTotal =>
      trialBalance.fold(0, (sum, row) => sum + row.creditAmount);
}

class AccountingPage extends ConsumerStatefulWidget {
  const AccountingPage({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<AccountingPage> createState() => _AccountingPageState();
}

class _AccountingPageState extends ConsumerState<AccountingPage> {
  late final TextEditingController _periodController;
  late String _period;

  @override
  void initState() {
    super.initState();
    _period = _formatPeriod(DateTime.now());
    _periodController = TextEditingController(text: _period);
  }

  @override
  void dispose() {
    _periodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = _AccountingCopy.of(context);
    final query = (workspaceId: widget.workspaceId, period: _period);
    final dashboardAsync = ref.watch(_accountingDashboardProvider(query));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(copy.title),
        actions: [
          IconButton(
            tooltip: copy.refresh,
            onPressed: widget.workspaceId.isEmpty
                ? null
                : () => ref.invalidate(_accountingDashboardProvider(query)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: widget.workspaceId.isEmpty
            ? _EmptyState(message: copy.workspaceRequired)
            : dashboardAsync.when(
                data: (dashboard) => _DashboardContent(
                  workspaceId: widget.workspaceId,
                  period: _period,
                  periodController: _periodController,
                  dashboard: dashboard,
                  onApplyPeriod: () {
                    final value = _periodController.text.trim();
                    if (RegExp(r'^\d{4}-\d{2}$').hasMatch(value)) {
                      setState(() {
                        _period = value;
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(copy.periodFormatError)),
                      );
                    }
                  },
                  onCreateAccount: () async {
                    final created = await _showCreateAccountDialog(
                      context: context,
                      ref: ref,
                      workspaceId: widget.workspaceId,
                    );
                    if (created) {
                      ref.invalidate(_accountingDashboardProvider(query));
                    }
                  },
                  onCreateVoucher: () async {
                    if (dashboard.accounts.length < 2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(copy.needAccounts)),
                      );
                      return;
                    }
                    final created = await _showCreateVoucherDialog(
                      context: context,
                      ref: ref,
                      workspaceId: widget.workspaceId,
                      accounts: dashboard.accounts,
                    );
                    if (created) {
                      ref.invalidate(_accountingDashboardProvider(query));
                    }
                  },
                  onPostVoucher: (voucherId) async {
                    try {
                      await ref
                          .read(accountingRepositoryProvider)
                          .postVoucher(
                            workspaceId: widget.workspaceId,
                            voucherId: voucherId,
                          );
                      ref.invalidate(_accountingDashboardProvider(query));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(copy.voucherPosted)),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    _EmptyState(message: '${copy.loadFailed}: $error'),
              ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.workspaceId,
    required this.period,
    required this.periodController,
    required this.dashboard,
    required this.onApplyPeriod,
    required this.onCreateAccount,
    required this.onCreateVoucher,
    required this.onPostVoucher,
  });

  final String workspaceId;
  final String period;
  final TextEditingController periodController;
  final AccountingDashboard dashboard;
  final VoidCallback onApplyPeriod;
  final Future<void> Function() onCreateAccount;
  final Future<void> Function() onCreateVoucher;
  final Future<void> Function(String voucherId) onPostVoucher;

  @override
  Widget build(BuildContext context) {
    final copy = _AccountingCopy.of(context);

    return DefaultTabController(
      length: 3,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AccountingHeader(
              workspaceId: workspaceId,
              period: period,
              periodController: periodController,
              dashboard: dashboard,
              onApplyPeriod: onApplyPeriod,
              onCreateAccount: onCreateAccount,
              onCreateVoucher: onCreateVoucher,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: TabBar(
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.receipt_long_rounded),
                      text: copy.vouchers,
                    ),
                    Tab(
                      icon: const Icon(Icons.account_tree_rounded),
                      text: copy.accounts,
                    ),
                    Tab(
                      icon: const Icon(Icons.balance_rounded),
                      text: copy.trialBalance,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _VoucherList(
                    vouchers: dashboard.vouchers,
                    onPostVoucher: onPostVoucher,
                  ),
                  _AccountList(accounts: dashboard.accounts),
                  _TrialBalanceTable(rows: dashboard.trialBalance),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountingHeader extends StatelessWidget {
  const _AccountingHeader({
    required this.workspaceId,
    required this.period,
    required this.periodController,
    required this.dashboard,
    required this.onApplyPeriod,
    required this.onCreateAccount,
    required this.onCreateVoucher,
  });

  final String workspaceId;
  final String period;
  final TextEditingController periodController;
  final AccountingDashboard dashboard;
  final VoidCallback onApplyPeriod;
  final Future<void> Function() onCreateAccount;
  final Future<void> Function() onCreateVoucher;

  @override
  Widget build(BuildContext context) {
    final copy = _AccountingCopy.of(context);
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Container(
        padding: EdgeInsets.all(compact ? 14 : 18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppPill(
                  label: '${copy.workspace}: $workspaceId',
                  icon: Icons.hub_rounded,
                ),
                AppPill(
                  label: '${copy.period}: $period',
                  icon: Icons.calendar_month_rounded,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricTile(
                  label: copy.accounts,
                  value: '${dashboard.accounts.length}',
                  icon: Icons.account_tree_rounded,
                  color: const Color(0xFF3D7EA6),
                ),
                _MetricTile(
                  label: copy.postedVouchers,
                  value: '${dashboard.postedVoucherCount}',
                  icon: Icons.task_alt_rounded,
                  color: const Color(0xFF1F8A5C),
                ),
                _MetricTile(
                  label: copy.debit,
                  value: _money(dashboard.periodDebitTotal),
                  icon: Icons.south_west_rounded,
                  color: const Color(0xFF7A5CBE),
                ),
                _MetricTile(
                  label: copy.credit,
                  value: _money(dashboard.periodCreditTotal),
                  icon: Icons.north_east_rounded,
                  color: const Color(0xFFC86A3B),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: compact ? 170 : 180,
                  child: TextField(
                    controller: periodController,
                    decoration: InputDecoration(
                      labelText: copy.period,
                      prefixIcon: const Icon(Icons.calendar_month_rounded),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                      LengthLimitingTextInputFormatter(7),
                    ],
                    onSubmitted: (_) => onApplyPeriod(),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onApplyPeriod,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: Text(copy.apply),
                ),
                OutlinedButton.icon(
                  onPressed: onCreateAccount,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(copy.newAccount),
                ),
                FilledButton.tonalIcon(
                  onPressed: onCreateVoucher,
                  icon: const Icon(Icons.post_add_rounded, size: 18),
                  label: Text(copy.newVoucher),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 176,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.22 : 0.46,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.62,
                      ),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoucherList extends StatelessWidget {
  const _VoucherList({required this.vouchers, required this.onPostVoucher});

  final List<AccountingVoucher> vouchers;
  final Future<void> Function(String voucherId) onPostVoucher;

  @override
  Widget build(BuildContext context) {
    final copy = _AccountingCopy.of(context);
    if (vouchers.isEmpty) {
      return _EmptyState(message: copy.noVouchers);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemBuilder: (context, index) {
        final voucher = vouchers[index];
        return _VoucherCard(
          voucher: voucher,
          onPost: voucher.isDraft ? () => onPostVoucher(voucher.id) : null,
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemCount: vouchers.length,
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({required this.voucher, required this.onPost});

  final AccountingVoucher voucher;
  final VoidCallback? onPost;

  @override
  Widget build(BuildContext context) {
    final copy = _AccountingCopy.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voucher.voucherNo,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${voucher.voucherDate}  ${voucher.description}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.66,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusBadge(
                label: _statusLabel(copy, voucher.status),
                color: _statusColor(voucher.status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              AppPill(
                label: '${copy.debit} ${_money(voucher.totalDebit)}',
                icon: Icons.south_west_rounded,
              ),
              AppPill(
                label: '${copy.credit} ${_money(voucher.totalCredit)}',
                icon: Icons.north_east_rounded,
              ),
              AppPill(
                label: '${voucher.lines.length} ${copy.lines}',
                icon: Icons.format_list_numbered_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...voucher.lines.map((line) => _VoucherLineRow(line: line)),
          if (onPost != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: onPost,
                icon: const Icon(Icons.task_alt_rounded, size: 18),
                label: Text(copy.postVoucher),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VoucherLineRow extends StatelessWidget {
  const _VoucherLineRow({required this.line});

  final AccountingVoucherLine line;

  @override
  Widget build(BuildContext context) {
    final copy = _AccountingCopy.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              '#${line.lineNo}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.56),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${line.accountCode} ${line.accountName}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (line.summary.isNotEmpty)
                  Text(
                    line.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(
              line.debitAmount > 0
                  ? '${copy.debit} ${_money(line.debitAmount)}'
                  : '${copy.credit} ${_money(line.creditAmount)}',
              textAlign: TextAlign.right,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountList extends StatelessWidget {
  const _AccountList({required this.accounts});

  final List<AccountingAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final copy = _AccountingCopy.of(context);
    final theme = Theme.of(context);
    if (accounts.isEmpty) {
      return _EmptyState(message: copy.noAccounts);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemBuilder: (context, index) {
        final account = accounts[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  _accountMarker(account.code),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${account.code} ${account.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_categoryLabel(copy, account.category)} / ${_balanceLabel(copy, account.normalBalance)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.64,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: account.active ? copy.enabled : copy.disabled,
                color: account.active
                    ? const Color(0xFF1F8A5C)
                    : const Color(0xFF7A8791),
              ),
            ],
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemCount: accounts.length,
    );
  }
}

class _TrialBalanceTable extends StatelessWidget {
  const _TrialBalanceTable({required this.rows});

  final List<TrialBalanceRow> rows;

  @override
  Widget build(BuildContext context) {
    final copy = _AccountingCopy.of(context);
    final theme = Theme.of(context);
    if (rows.isEmpty) {
      return _EmptyState(message: copy.noTrialBalance);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(label: Text(copy.account)),
                DataColumn(label: Text(copy.category)),
                DataColumn(label: Text(copy.debit)),
                DataColumn(label: Text(copy.credit)),
                DataColumn(label: Text(copy.balance)),
              ],
              rows: rows
                  .map(
                    (row) => DataRow(
                      cells: [
                        DataCell(Text('${row.accountCode} ${row.accountName}')),
                        DataCell(Text(_categoryLabel(copy, row.category))),
                        DataCell(Text(_money(row.debitAmount))),
                        DataCell(Text(_money(row.creditAmount))),
                        DataCell(
                          Text(
                            '${_money(row.balanceAmount)} ${_balanceLabel(copy, row.balanceDirection)}',
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

Future<bool> _showCreateAccountDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String workspaceId,
}) async {
  final copy = _AccountingCopy.of(context);
  final codeController = TextEditingController();
  final nameController = TextEditingController();
  var category = 'ASSET';
  var normalBalance = 'DEBIT';
  try {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var isSaving = false;
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> save() async {
              final code = codeController.text.trim();
              final name = nameController.text.trim();
              if (code.isEmpty || name.isEmpty) {
                setState(() {
                  errorText = copy.requiredFields;
                });
                return;
              }
              setState(() {
                isSaving = true;
                errorText = null;
              });
              try {
                await ref
                    .read(accountingRepositoryProvider)
                    .createAccount(
                      workspaceId: workspaceId,
                      code: code,
                      name: name,
                      category: category,
                      normalBalance: normalBalance,
                    );
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                }
              } catch (error) {
                setState(() {
                  errorText = error.toString();
                  isSaving = false;
                });
              }
            }

            return AlertDialog(
              title: Text(copy.newAccount),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeController,
                      enabled: !isSaving,
                      decoration: InputDecoration(labelText: copy.accountCode),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      enabled: !isSaving,
                      decoration: InputDecoration(labelText: copy.accountName),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(labelText: copy.category),
                      items: _categories
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_categoryLabel(copy, value)),
                            ),
                          )
                          .toList(),
                      onChanged: isSaving
                          ? null
                          : (value) => setState(() {
                              category = value ?? category;
                            }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: normalBalance,
                      decoration: InputDecoration(
                        labelText: copy.normalBalance,
                      ),
                      items: _balanceDirections
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_balanceLabel(copy, value)),
                            ),
                          )
                          .toList(),
                      onChanged: isSaving
                          ? null
                          : (value) => setState(() {
                              normalBalance = value ?? normalBalance;
                            }),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFBA3B2F),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(copy.cancel),
                ),
                FilledButton(
                  onPressed: isSaving ? null : save,
                  child: Text(isSaving ? copy.saving : copy.save),
                ),
              ],
            );
          },
        );
      },
    );
    return result ?? false;
  } finally {
    codeController.dispose();
    nameController.dispose();
  }
}

Future<bool> _showCreateVoucherDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String workspaceId,
  required List<AccountingAccount> accounts,
}) async {
  final copy = _AccountingCopy.of(context);
  final dateController = TextEditingController(
    text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
  );
  final descriptionController = TextEditingController();
  final lineEditors = [
    _VoucherLineEditor(accountId: accounts.first.id),
    _VoucherLineEditor(accountId: accounts[1].id),
  ];
  try {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var isSaving = false;
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> save() async {
              final date = dateController.text.trim();
              if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
                setState(() {
                  errorText = copy.dateFormatError;
                });
                return;
              }
              final lines = lineEditors
                  .map(
                    (editor) => CreateAccountingVoucherLineInput(
                      accountId: editor.accountId,
                      summary: editor.summaryController.text.trim(),
                      debitAmount: _parseMoney(editor.debitController.text),
                      creditAmount: _parseMoney(editor.creditController.text),
                    ),
                  )
                  .toList();
              setState(() {
                isSaving = true;
                errorText = null;
              });
              try {
                await ref
                    .read(accountingRepositoryProvider)
                    .createVoucher(
                      workspaceId: workspaceId,
                      voucherDate: date,
                      description: descriptionController.text.trim(),
                      lines: lines,
                    );
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                }
              } catch (error) {
                setState(() {
                  errorText = error.toString();
                  isSaving = false;
                });
              }
            }

            return AlertDialog(
              scrollable: true,
              title: Text(copy.newVoucher),
              content: SizedBox(
                width: 680,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 180,
                          child: TextField(
                            controller: dateController,
                            enabled: !isSaving,
                            decoration: InputDecoration(
                              labelText: copy.voucherDate,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9-]'),
                              ),
                              LengthLimitingTextInputFormatter(10),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: descriptionController,
                            enabled: !isSaving,
                            decoration: InputDecoration(
                              labelText: copy.description,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (var index = 0; index < lineEditors.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _VoucherLineEditorRow(
                          index: index,
                          editor: lineEditors[index],
                          accounts: accounts,
                          enabled: !isSaving,
                          onChanged: () => setState(() {}),
                          onRemove: lineEditors.length <= 2
                              ? null
                              : () {
                                  final editor = lineEditors.removeAt(index);
                                  editor.dispose();
                                  setState(() {});
                                },
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: isSaving
                            ? null
                            : () {
                                lineEditors.add(
                                  _VoucherLineEditor(
                                    accountId: accounts.first.id,
                                  ),
                                );
                                setState(() {});
                              },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(copy.addLine),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFBA3B2F),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(copy.cancel),
                ),
                FilledButton(
                  onPressed: isSaving ? null : save,
                  child: Text(isSaving ? copy.saving : copy.save),
                ),
              ],
            );
          },
        );
      },
    );
    return result ?? false;
  } finally {
    dateController.dispose();
    descriptionController.dispose();
    for (final editor in lineEditors) {
      editor.dispose();
    }
  }
}

class _VoucherLineEditorRow extends StatelessWidget {
  const _VoucherLineEditorRow({
    required this.index,
    required this.editor,
    required this.accounts,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _VoucherLineEditor editor;
  final List<AccountingAccount> accounts;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final copy = _AccountingCopy.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final accountPicker = DropdownButtonFormField<String>(
          initialValue: editor.accountId,
          isExpanded: true,
          decoration: InputDecoration(labelText: copy.account),
          items: accounts
              .map(
                (account) => DropdownMenuItem(
                  value: account.id,
                  child: Text('${account.code} ${account.name}'),
                ),
              )
              .toList(),
          onChanged: enabled
              ? (value) {
                  editor.accountId = value ?? editor.accountId;
                  onChanged();
                }
              : null,
        );
        final summary = TextField(
          controller: editor.summaryController,
          enabled: enabled,
          decoration: InputDecoration(labelText: copy.summary),
        );
        final debit = TextField(
          controller: editor.debitController,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: copy.debit),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
        );
        final credit = TextField(
          controller: editor.creditController,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: copy.credit),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
        );
        final removeButton = IconButton(
          tooltip: copy.removeLine,
          onPressed: enabled ? onRemove : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        );

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: compact
              ? Column(
                  children: [
                    Row(
                      children: [
                        Text('#${index + 1}'),
                        const SizedBox(width: 8),
                        Expanded(child: accountPicker),
                        removeButton,
                      ],
                    ),
                    const SizedBox(height: 10),
                    summary,
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: debit),
                        const SizedBox(width: 10),
                        Expanded(child: credit),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(width: 28, child: Text('#${index + 1}')),
                    Expanded(flex: 3, child: accountPicker),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: summary),
                    const SizedBox(width: 10),
                    SizedBox(width: 96, child: debit),
                    const SizedBox(width: 10),
                    SizedBox(width: 96, child: credit),
                    removeButton,
                  ],
                ),
        );
      },
    );
  }
}

class _VoucherLineEditor {
  _VoucherLineEditor({required this.accountId});

  String accountId;
  final summaryController = TextEditingController();
  final debitController = TextEditingController();
  final creditController = TextEditingController();

  void dispose() {
    summaryController.dispose();
    debitController.dispose();
    creditController.dispose();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }
}

const _categories = ['ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE'];
const _balanceDirections = ['DEBIT', 'CREDIT'];

String _categoryLabel(_AccountingCopy copy, String value) {
  return switch (value) {
    'ASSET' => copy.asset,
    'LIABILITY' => copy.liability,
    'EQUITY' => copy.equity,
    'REVENUE' => copy.revenue,
    'EXPENSE' => copy.expense,
    _ => value,
  };
}

String _balanceLabel(_AccountingCopy copy, String value) {
  return switch (value) {
    'DEBIT' => copy.debitDirection,
    'CREDIT' => copy.creditDirection,
    _ => value,
  };
}

String _statusLabel(_AccountingCopy copy, String status) {
  return switch (status) {
    'DRAFT' => copy.draft,
    'POSTED' => copy.posted,
    _ => status,
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'POSTED' => const Color(0xFF1F8A5C),
    'DRAFT' => const Color(0xFF3D7EA6),
    _ => const Color(0xFF7A8791),
  };
}

String _money(double value) {
  return NumberFormat.currency(symbol: '', decimalDigits: 2).format(value);
}

String _accountMarker(String code) {
  final trimmed = code.trim();
  if (trimmed.isEmpty) {
    return '--';
  }
  if (trimmed.length <= 2) {
    return trimmed;
  }
  return trimmed.substring(0, 2);
}

double _parseMoney(String value) {
  return double.tryParse(value.trim()) ?? 0;
}

String _formatPeriod(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

class _AccountingCopy {
  const _AccountingCopy({
    required this.title,
    required this.refresh,
    required this.workspaceRequired,
    required this.loadFailed,
    required this.workspace,
    required this.period,
    required this.apply,
    required this.vouchers,
    required this.accounts,
    required this.trialBalance,
    required this.postedVouchers,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.lines,
    required this.account,
    required this.accountCode,
    required this.accountName,
    required this.category,
    required this.normalBalance,
    required this.newAccount,
    required this.newVoucher,
    required this.voucherDate,
    required this.description,
    required this.summary,
    required this.addLine,
    required this.removeLine,
    required this.postVoucher,
    required this.voucherPosted,
    required this.needAccounts,
    required this.noAccounts,
    required this.noVouchers,
    required this.noTrialBalance,
    required this.requiredFields,
    required this.periodFormatError,
    required this.dateFormatError,
    required this.save,
    required this.saving,
    required this.cancel,
    required this.enabled,
    required this.disabled,
    required this.asset,
    required this.liability,
    required this.equity,
    required this.revenue,
    required this.expense,
    required this.debitDirection,
    required this.creditDirection,
    required this.draft,
    required this.posted,
  });

  final String title;
  final String refresh;
  final String workspaceRequired;
  final String loadFailed;
  final String workspace;
  final String period;
  final String apply;
  final String vouchers;
  final String accounts;
  final String trialBalance;
  final String postedVouchers;
  final String debit;
  final String credit;
  final String balance;
  final String lines;
  final String account;
  final String accountCode;
  final String accountName;
  final String category;
  final String normalBalance;
  final String newAccount;
  final String newVoucher;
  final String voucherDate;
  final String description;
  final String summary;
  final String addLine;
  final String removeLine;
  final String postVoucher;
  final String voucherPosted;
  final String needAccounts;
  final String noAccounts;
  final String noVouchers;
  final String noTrialBalance;
  final String requiredFields;
  final String periodFormatError;
  final String dateFormatError;
  final String save;
  final String saving;
  final String cancel;
  final String enabled;
  final String disabled;
  final String asset;
  final String liability;
  final String equity;
  final String revenue;
  final String expense;
  final String debitDirection;
  final String creditDirection;
  final String draft;
  final String posted;

  static _AccountingCopy of(BuildContext context) {
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';
    if (isChinese) {
      return const _AccountingCopy(
        title: '\u4f1a\u8ba1\u603b\u8d26',
        refresh: '\u5237\u65b0',
        workspaceRequired:
            '\u7f3a\u5c11\u5de5\u4f5c\u533a\u4e0a\u4e0b\u6587\u3002',
        loadFailed: '\u52a0\u8f7d\u4f1a\u8ba1\u6570\u636e\u5931\u8d25',
        workspace: '\u5de5\u4f5c\u533a',
        period: '\u671f\u95f4',
        apply: '\u5e94\u7528',
        vouchers: '\u51ed\u8bc1',
        accounts: '\u79d1\u76ee',
        trialBalance: '\u8bd5\u7b97\u5e73\u8861',
        postedVouchers: '\u5df2\u8fc7\u8d26\u51ed\u8bc1',
        debit: '\u501f\u65b9',
        credit: '\u8d37\u65b9',
        balance: '\u4f59\u989d',
        lines: '\u884c',
        account: '\u79d1\u76ee',
        accountCode: '\u79d1\u76ee\u7f16\u7801',
        accountName: '\u79d1\u76ee\u540d\u79f0',
        category: '\u7c7b\u522b',
        normalBalance: '\u4f59\u989d\u65b9\u5411',
        newAccount: '\u65b0\u5efa\u79d1\u76ee',
        newVoucher: '\u65b0\u5efa\u51ed\u8bc1',
        voucherDate: '\u51ed\u8bc1\u65e5\u671f',
        description: '\u8bf4\u660e',
        summary: '\u6458\u8981',
        addLine: '\u6dfb\u52a0\u5206\u5f55',
        removeLine: '\u79fb\u9664\u5206\u5f55',
        postVoucher: '\u8fc7\u8d26',
        voucherPosted: '\u51ed\u8bc1\u5df2\u8fc7\u8d26',
        needAccounts:
            '\u81f3\u5c11\u9700\u8981\u4e24\u4e2a\u79d1\u76ee\u624d\u80fd\u5f55\u5165\u51ed\u8bc1\u3002',
        noAccounts:
            '\u8fd8\u6ca1\u6709\u79d1\u76ee\u3002\u5148\u65b0\u5efa\u79d1\u76ee\u8868\u3002',
        noVouchers: '\u8fd8\u6ca1\u6709\u51ed\u8bc1\u3002',
        noTrialBalance:
            '\u5f53\u524d\u671f\u95f4\u6ca1\u6709\u8bd5\u7b97\u6570\u636e\u3002',
        requiredFields: '\u8bf7\u586b\u5199\u5fc5\u586b\u5b57\u6bb5\u3002',
        periodFormatError:
            '\u671f\u95f4\u683c\u5f0f\u5fc5\u987b\u662f yyyy-MM\u3002',
        dateFormatError:
            '\u65e5\u671f\u683c\u5f0f\u5fc5\u987b\u662f yyyy-MM-dd\u3002',
        save: '\u4fdd\u5b58',
        saving: '\u4fdd\u5b58\u4e2d...',
        cancel: '\u53d6\u6d88',
        enabled: '\u542f\u7528',
        disabled: '\u505c\u7528',
        asset: '\u8d44\u4ea7',
        liability: '\u8d1f\u503a',
        equity: '\u6743\u76ca',
        revenue: '\u6536\u5165',
        expense: '\u8d39\u7528',
        debitDirection: '\u501f',
        creditDirection: '\u8d37',
        draft: '\u8349\u7a3f',
        posted: '\u5df2\u8fc7\u8d26',
      );
    }
    return const _AccountingCopy(
      title: 'Accounting',
      refresh: 'Refresh',
      workspaceRequired: 'No workspace context is available.',
      loadFailed: 'Failed to load accounting data',
      workspace: 'Workspace',
      period: 'Period',
      apply: 'Apply',
      vouchers: 'Vouchers',
      accounts: 'Accounts',
      trialBalance: 'Trial balance',
      postedVouchers: 'Posted vouchers',
      debit: 'Debit',
      credit: 'Credit',
      balance: 'Balance',
      lines: 'lines',
      account: 'Account',
      accountCode: 'Account code',
      accountName: 'Account name',
      category: 'Category',
      normalBalance: 'Normal balance',
      newAccount: 'New account',
      newVoucher: 'New voucher',
      voucherDate: 'Voucher date',
      description: 'Description',
      summary: 'Summary',
      addLine: 'Add line',
      removeLine: 'Remove line',
      postVoucher: 'Post voucher',
      voucherPosted: 'Voucher posted',
      needAccounts: 'Create at least two accounts before entering a voucher.',
      noAccounts: 'No accounts yet. Create a chart of accounts first.',
      noVouchers: 'No vouchers yet.',
      noTrialBalance: 'No trial balance activity for this period.',
      requiredFields: 'Fill the required fields.',
      periodFormatError: 'Period must use yyyy-MM format.',
      dateFormatError: 'Date must use yyyy-MM-dd format.',
      save: 'Save',
      saving: 'Saving...',
      cancel: 'Cancel',
      enabled: 'Enabled',
      disabled: 'Disabled',
      asset: 'Asset',
      liability: 'Liability',
      equity: 'Equity',
      revenue: 'Revenue',
      expense: 'Expense',
      debitDirection: 'Debit',
      creditDirection: 'Credit',
      draft: 'Draft',
      posted: 'Posted',
    );
  }
}
