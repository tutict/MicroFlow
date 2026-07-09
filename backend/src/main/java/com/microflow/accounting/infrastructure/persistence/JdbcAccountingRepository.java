package com.microflow.accounting.infrastructure.persistence;

import com.microflow.accounting.domain.model.AccountingAccount;
import com.microflow.accounting.domain.model.AccountingVoucher;
import com.microflow.accounting.domain.model.AccountingVoucherLine;
import com.microflow.accounting.domain.model.TrialBalanceRow;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcAccountingRepository {

    private static final BigDecimal ZERO = BigDecimal.ZERO.setScale(2);
    private static final RowMapper<AccountingAccount> ACCOUNT_MAPPER = JdbcAccountingRepository::mapAccount;
    private static final RowMapper<AccountingVoucherLine> LINE_MAPPER = JdbcAccountingRepository::mapLine;
    private static final RowMapper<TrialBalanceRow> TRIAL_BALANCE_ROW_MAPPER =
            JdbcAccountingRepository::mapTrialBalanceRow;

    private final JdbcTemplate jdbcTemplate;

    public JdbcAccountingRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<AccountingAccount> listAccounts(String workspaceId) {
        return jdbcTemplate.query("""
                SELECT id, workspace_id, code, name, category, normal_balance, active, created_at, updated_at
                FROM accounting_accounts
                WHERE workspace_id = ?
                ORDER BY code ASC
                """, ACCOUNT_MAPPER, workspaceId);
    }

    public Optional<AccountingAccount> findAccountById(String workspaceId, String accountId) {
        return jdbcTemplate.query("""
                SELECT id, workspace_id, code, name, category, normal_balance, active, created_at, updated_at
                FROM accounting_accounts
                WHERE workspace_id = ? AND id = ?
                """, ACCOUNT_MAPPER, workspaceId, accountId).stream().findFirst();
    }

    public boolean accountCodeExists(String workspaceId, String code) {
        var count = jdbcTemplate.queryForObject("""
                SELECT COUNT(1)
                FROM accounting_accounts
                WHERE workspace_id = ? AND code = ?
                """, Integer.class, workspaceId, code);
        return count != null && count > 0;
    }

    public AccountingAccount createAccount(
            String id,
            String workspaceId,
            String code,
            String name,
            String category,
            String normalBalance,
            String now
    ) {
        jdbcTemplate.update("""
                INSERT INTO accounting_accounts(
                    id, workspace_id, code, name, category, normal_balance, active, created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
                """,
                id,
                workspaceId,
                code,
                name,
                category,
                normalBalance,
                now,
                now
        );
        return findAccountById(workspaceId, id)
                .orElseThrow(() -> new IllegalStateException("Created account could not be loaded"));
    }

    public List<AccountingVoucher> listVouchers(String workspaceId) {
        var records = jdbcTemplate.query("""
                SELECT id, workspace_id, voucher_no, voucher_date, period, status, description,
                       created_by_user_id, created_at, updated_at, posted_at
                FROM accounting_vouchers
                WHERE workspace_id = ?
                ORDER BY voucher_date DESC, created_at DESC
                """, JdbcAccountingRepository::mapVoucherRecord, workspaceId);
        return hydrateVouchers(records);
    }

    public Optional<AccountingVoucher> findVoucher(String workspaceId, String voucherId) {
        var records = jdbcTemplate.query("""
                SELECT id, workspace_id, voucher_no, voucher_date, period, status, description,
                       created_by_user_id, created_at, updated_at, posted_at
                FROM accounting_vouchers
                WHERE workspace_id = ? AND id = ?
                """, JdbcAccountingRepository::mapVoucherRecord, workspaceId, voucherId);
        return hydrateVouchers(records).stream().findFirst();
    }

    public int countVouchersForPeriod(String workspaceId, String period) {
        var count = jdbcTemplate.queryForObject("""
                SELECT COUNT(1)
                FROM accounting_vouchers
                WHERE workspace_id = ? AND period = ?
                """, Integer.class, workspaceId, period);
        return count == null ? 0 : count;
    }

    public AccountingVoucher createVoucher(
            String id,
            String workspaceId,
            String voucherNo,
            String voucherDate,
            String period,
            String description,
            String createdByUserId,
            String now,
            List<AccountingVoucherLine> lines
    ) {
        jdbcTemplate.update("""
                INSERT INTO accounting_vouchers(
                    id, workspace_id, voucher_no, voucher_date, period, status, description,
                    created_by_user_id, created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, 'DRAFT', ?, ?, ?, ?)
                """,
                id,
                workspaceId,
                voucherNo,
                voucherDate,
                period,
                description,
                createdByUserId,
                now,
                now
        );
        batchInsertLines(id, lines);
        return findVoucher(workspaceId, id)
                .orElseThrow(() -> new IllegalStateException("Created voucher could not be loaded"));
    }

    public AccountingVoucher postVoucher(String workspaceId, String voucherId, String now) {
        jdbcTemplate.update("""
                UPDATE accounting_vouchers
                SET status = 'POSTED',
                    posted_at = ?,
                    updated_at = ?
                WHERE workspace_id = ? AND id = ? AND status = 'DRAFT'
                """, now, now, workspaceId, voucherId);
        return findVoucher(workspaceId, voucherId)
                .orElseThrow(() -> new IllegalArgumentException("Voucher not found"));
    }

    public List<TrialBalanceRow> trialBalance(String workspaceId, String period) {
        return jdbcTemplate.query("""
                SELECT a.id AS account_id,
                       a.code AS account_code,
                       a.name AS account_name,
                       a.category,
                       a.normal_balance,
                       COALESCE(SUM(CASE WHEN v.id IS NOT NULL THEN l.debit_amount ELSE 0 END), 0) AS debit_amount,
                       COALESCE(SUM(CASE WHEN v.id IS NOT NULL THEN l.credit_amount ELSE 0 END), 0) AS credit_amount
                FROM accounting_accounts a
                LEFT JOIN accounting_voucher_lines l ON l.account_id = a.id
                LEFT JOIN accounting_vouchers v
                  ON v.id = l.voucher_id
                 AND v.status = 'POSTED'
                 AND (? IS NULL OR v.period = ?)
                WHERE a.workspace_id = ?
                GROUP BY a.id, a.code, a.name, a.category, a.normal_balance
                ORDER BY a.code ASC
                """, TRIAL_BALANCE_ROW_MAPPER, period, period, workspaceId);
    }

    private void batchInsertLines(String voucherId, List<AccountingVoucherLine> lines) {
        jdbcTemplate.batchUpdate("""
                INSERT INTO accounting_voucher_lines(
                    id, voucher_id, line_no, account_id, summary, debit_amount, credit_amount
                )
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """, lines, lines.size(), (PreparedStatement ps, AccountingVoucherLine line) -> {
            ps.setString(1, line.id());
            ps.setString(2, voucherId);
            ps.setInt(3, line.lineNo());
            ps.setString(4, line.accountId());
            ps.setString(5, line.summary());
            ps.setBigDecimal(6, line.debitAmount());
            ps.setBigDecimal(7, line.creditAmount());
        });
    }

    private List<AccountingVoucher> hydrateVouchers(List<VoucherRecord> records) {
        if (records.isEmpty()) {
            return List.of();
        }
        var linesByVoucherId = listLinesByVoucherId(records.stream()
                .map(VoucherRecord::id)
                .toList());
        return records.stream()
                .map(record -> toVoucher(record, linesByVoucherId.getOrDefault(record.id(), List.of())))
                .toList();
    }

    private Map<String, List<AccountingVoucherLine>> listLinesByVoucherId(List<String> voucherIds) {
        var placeholders = String.join(",", voucherIds.stream().map(id -> "?").toList());
        var lines = jdbcTemplate.query("""
                SELECT l.id, l.voucher_id, l.line_no, l.account_id, a.code AS account_code,
                       a.name AS account_name, l.summary, l.debit_amount, l.credit_amount
                FROM accounting_voucher_lines l
                JOIN accounting_accounts a ON a.id = l.account_id
                WHERE l.voucher_id IN (%s)
                ORDER BY l.voucher_id ASC, l.line_no ASC
                """.formatted(placeholders), LINE_MAPPER, voucherIds.toArray());
        var grouped = new LinkedHashMap<String, List<AccountingVoucherLine>>();
        for (var line : lines) {
            grouped.computeIfAbsent(line.voucherId(), id -> new ArrayList<>()).add(line);
        }
        return grouped;
    }

    private static AccountingVoucher toVoucher(VoucherRecord record, List<AccountingVoucherLine> lines) {
        var totalDebit = lines.stream()
                .map(AccountingVoucherLine::debitAmount)
                .reduce(ZERO, BigDecimal::add);
        var totalCredit = lines.stream()
                .map(AccountingVoucherLine::creditAmount)
                .reduce(ZERO, BigDecimal::add);
        return new AccountingVoucher(
                record.id(),
                record.workspaceId(),
                record.voucherNo(),
                record.voucherDate(),
                record.period(),
                record.status(),
                record.description(),
                totalDebit,
                totalCredit,
                record.createdByUserId(),
                record.createdAt(),
                record.updatedAt(),
                record.postedAt(),
                lines
        );
    }

    private static VoucherRecord mapVoucherRecord(ResultSet rs, int rowNum) throws SQLException {
        return new VoucherRecord(
                rs.getString("id"),
                rs.getString("workspace_id"),
                rs.getString("voucher_no"),
                rs.getString("voucher_date"),
                rs.getString("period"),
                rs.getString("status"),
                rs.getString("description"),
                rs.getString("created_by_user_id"),
                rs.getString("created_at"),
                rs.getString("updated_at"),
                rs.getString("posted_at")
        );
    }

    private static AccountingAccount mapAccount(ResultSet rs, int rowNum) throws SQLException {
        return new AccountingAccount(
                rs.getString("id"),
                rs.getString("workspace_id"),
                rs.getString("code"),
                rs.getString("name"),
                rs.getString("category"),
                rs.getString("normal_balance"),
                rs.getInt("active") == 1,
                rs.getString("created_at"),
                rs.getString("updated_at")
        );
    }

    private static AccountingVoucherLine mapLine(ResultSet rs, int rowNum) throws SQLException {
        return new AccountingVoucherLine(
                rs.getString("id"),
                rs.getString("voucher_id"),
                rs.getInt("line_no"),
                rs.getString("account_id"),
                rs.getString("account_code"),
                rs.getString("account_name"),
                rs.getString("summary"),
                decimal(rs, "debit_amount"),
                decimal(rs, "credit_amount")
        );
    }

    private static TrialBalanceRow mapTrialBalanceRow(ResultSet rs, int rowNum) throws SQLException {
        var debit = decimal(rs, "debit_amount");
        var credit = decimal(rs, "credit_amount");
        var normalBalance = rs.getString("normal_balance");
        var signedBalance = "CREDIT".equals(normalBalance) ? credit.subtract(debit) : debit.subtract(credit);
        var direction = signedBalance.signum() < 0
                ? ("CREDIT".equals(normalBalance) ? "DEBIT" : "CREDIT")
                : normalBalance;
        return new TrialBalanceRow(
                rs.getString("account_id"),
                rs.getString("account_code"),
                rs.getString("account_name"),
                rs.getString("category"),
                normalBalance,
                debit,
                credit,
                signedBalance.abs(),
                direction
        );
    }

    private static BigDecimal decimal(ResultSet rs, String columnName) throws SQLException {
        var value = rs.getBigDecimal(columnName);
        return value == null ? ZERO : value.setScale(2, RoundingMode.HALF_UP);
    }

    private record VoucherRecord(
            String id,
            String workspaceId,
            String voucherNo,
            String voucherDate,
            String period,
            String status,
            String description,
            String createdByUserId,
            String createdAt,
            String updatedAt,
            String postedAt
    ) {
    }
}