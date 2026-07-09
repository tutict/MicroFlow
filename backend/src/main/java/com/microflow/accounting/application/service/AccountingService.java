package com.microflow.accounting.application.service;

import com.microflow.accounting.domain.model.AccountingAccount;
import com.microflow.accounting.domain.model.AccountingVoucher;
import com.microflow.accounting.domain.model.AccountingVoucherLine;
import com.microflow.accounting.domain.model.TrialBalanceRow;
import com.microflow.accounting.infrastructure.persistence.JdbcAccountingRepository;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import jakarta.transaction.Transactional;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;

@Service
public class AccountingService {

    private static final Set<String> ACCOUNT_CATEGORIES = Set.of(
            "ASSET", "LIABILITY", "EQUITY", "REVENUE", "EXPENSE"
    );
    private static final Set<String> BALANCE_DIRECTIONS = Set.of("DEBIT", "CREDIT");
    private static final BigDecimal ZERO = BigDecimal.ZERO.setScale(2);
    private static final int VOUCHER_CREATE_MAX_ATTEMPTS = 3;

    private final JdbcAccountingRepository accountingRepository;
    private final JdbcWorkspaceRepository workspaceRepository;
    private final Clock clock;

    public AccountingService(
            JdbcAccountingRepository accountingRepository,
            JdbcWorkspaceRepository workspaceRepository,
            Clock clock
    ) {
        this.accountingRepository = accountingRepository;
        this.workspaceRepository = workspaceRepository;
        this.clock = clock;
    }

    public List<AccountingAccount> listAccounts(String workspaceId, String userId) {
        ensureWorkspaceMember(workspaceId, userId);
        return accountingRepository.listAccounts(workspaceId);
    }

    @Transactional
    public AccountingAccount createAccount(
            String workspaceId,
            String userId,
            String code,
            String name,
            String category,
            String normalBalance
    ) {
        ensureWorkspaceMember(workspaceId, userId);
        var normalizedCode = normalizeRequired(code, "Account code is required");
        var normalizedName = normalizeRequired(name, "Account name is required");
        var normalizedCategory = normalizeEnum(category, ACCOUNT_CATEGORIES, "Unsupported account category");
        var normalizedBalance = normalizeEnum(normalBalance, BALANCE_DIRECTIONS, "Unsupported normal balance");
        if (accountingRepository.accountCodeExists(workspaceId, normalizedCode)) {
            throw new IllegalArgumentException("Account code already exists");
        }
        var now = Instant.now(clock).toString();
        return accountingRepository.createAccount(
                "acct_" + UUID.randomUUID(),
                workspaceId,
                normalizedCode,
                normalizedName,
                normalizedCategory,
                normalizedBalance,
                now
        );
    }

    public List<AccountingVoucher> listVouchers(String workspaceId, String userId) {
        ensureWorkspaceMember(workspaceId, userId);
        return accountingRepository.listVouchers(workspaceId);
    }

    @Transactional
    public AccountingVoucher createVoucher(
            String workspaceId,
            String userId,
            String voucherDate,
            String description,
            List<VoucherLineInput> lineInputs
    ) {
        ensureWorkspaceMember(workspaceId, userId);
        if (lineInputs == null || lineInputs.size() < 2) {
            throw new IllegalArgumentException("A voucher requires at least two lines");
        }
        var parsedDate = parseVoucherDate(voucherDate);
        var normalizedDescription = description == null ? "" : description.trim();
        if (normalizedDescription.length() > 500) {
            throw new IllegalArgumentException("Voucher description must be 500 characters or fewer");
        }
        var period = parsedDate.getYear() + "-" + "%02d".formatted(parsedDate.getMonthValue());
        var lines = buildVoucherLines(workspaceId, normalizedDescription, lineInputs);
        var totalDebit = total(lines, true);
        var totalCredit = total(lines, false);
        if (totalDebit.compareTo(ZERO) <= 0 || totalCredit.compareTo(ZERO) <= 0) {
            throw new IllegalArgumentException("Voucher totals must be greater than zero");
        }
        if (totalDebit.compareTo(totalCredit) != 0) {
            throw new IllegalArgumentException("Voucher debit and credit totals must balance");
        }
        var now = Instant.now(clock).toString();
        for (var attempt = 1; attempt <= VOUCHER_CREATE_MAX_ATTEMPTS; attempt++) {
            var voucherId = "vch_" + UUID.randomUUID();
            var voucherNo = nextVoucherNo(workspaceId, period);
            try {
                return accountingRepository.createVoucher(
                        voucherId,
                        workspaceId,
                        voucherNo,
                        parsedDate.toString(),
                        period,
                        normalizedDescription,
                        userId,
                        now,
                        lines.stream()
                                .map(line -> new AccountingVoucherLine(
                                        line.id(),
                                        voucherId,
                                        line.lineNo(),
                                        line.accountId(),
                                        line.accountCode(),
                                        line.accountName(),
                                        line.summary(),
                                        line.debitAmount(),
                                        line.creditAmount()
                                ))
                                .toList()
                );
            } catch (DuplicateKeyException ex) {
                if (attempt == VOUCHER_CREATE_MAX_ATTEMPTS) {
                    throw ex;
                }
            }
        }
        throw new IllegalStateException("Unable to create voucher after retrying voucher number allocation");
    }

    @Transactional
    public AccountingVoucher postVoucher(String workspaceId, String userId, String voucherId) {
        ensureWorkspaceMember(workspaceId, userId);
        var voucher = accountingRepository.findVoucher(workspaceId, voucherId)
                .orElseThrow(() -> new IllegalArgumentException("Voucher not found"));
        if (!"DRAFT".equals(voucher.status())) {
            throw new IllegalArgumentException("Only draft vouchers can be posted");
        }
        if (voucher.totalDebit().compareTo(voucher.totalCredit()) != 0) {
            throw new IllegalArgumentException("Voucher debit and credit totals must balance");
        }
        return accountingRepository.postVoucher(workspaceId, voucherId, Instant.now(clock).toString());
    }

    public List<TrialBalanceRow> trialBalance(String workspaceId, String userId, String period) {
        ensureWorkspaceMember(workspaceId, userId);
        var normalizedPeriod = normalizePeriod(period);
        return accountingRepository.trialBalance(workspaceId, normalizedPeriod);
    }

    private List<PreparedVoucherLine> buildVoucherLines(
            String workspaceId,
            String voucherDescription,
            List<VoucherLineInput> lineInputs
    ) {
        return java.util.stream.IntStream.range(0, lineInputs.size())
                .mapToObj(index -> buildVoucherLine(workspaceId, voucherDescription, index + 1, lineInputs.get(index)))
                .toList();
    }

    private PreparedVoucherLine buildVoucherLine(
            String workspaceId,
            String voucherDescription,
            int lineNo,
            VoucherLineInput input
    ) {
        if (input == null) {
            throw new IllegalArgumentException("Voucher line cannot be null");
        }
        var accountId = normalizeRequired(input.accountId(), "Voucher line account is required");
        var account = accountingRepository.findAccountById(workspaceId, accountId)
                .orElseThrow(() -> new IllegalArgumentException("Voucher line account not found"));
        if (!account.active()) {
            throw new IllegalArgumentException("Voucher line account is inactive");
        }
        var debit = normalizeAmount(input.debitAmount(), "debitAmount");
        var credit = normalizeAmount(input.creditAmount(), "creditAmount");
        if (debit.compareTo(ZERO) > 0 && credit.compareTo(ZERO) > 0) {
            throw new IllegalArgumentException("A voucher line cannot have both debit and credit amounts");
        }
        if (debit.compareTo(ZERO) == 0 && credit.compareTo(ZERO) == 0) {
            throw new IllegalArgumentException("A voucher line requires a debit or credit amount");
        }
        var summary = input.summary() == null || input.summary().isBlank()
                ? voucherDescription
                : input.summary().trim();
        if (summary.length() > 500) {
            throw new IllegalArgumentException("Voucher line summary must be 500 characters or fewer");
        }
        return new PreparedVoucherLine(
                "vchl_" + UUID.randomUUID(),
                lineNo,
                account.id(),
                account.code(),
                account.name(),
                summary,
                debit,
                credit
        );
    }

    private BigDecimal total(List<PreparedVoucherLine> lines, boolean debit) {
        return lines.stream()
                .map(line -> debit ? line.debitAmount() : line.creditAmount())
                .reduce(ZERO, BigDecimal::add);
    }

    private String nextVoucherNo(String workspaceId, String period) {
        var sequence = accountingRepository.countVouchersForPeriod(workspaceId, period) + 1;
        return "GL-" + period.replace("-", "") + "-" + "%04d".formatted(sequence);
    }

    private void ensureWorkspaceMember(String workspaceId, String userId) {
        if (!workspaceRepository.isWorkspaceMember(workspaceId, userId)) {
            throw new IllegalArgumentException("Workspace access denied");
        }
    }

    private LocalDate parseVoucherDate(String voucherDate) {
        try {
            return LocalDate.parse(normalizeRequired(voucherDate, "Voucher date is required"));
        } catch (DateTimeParseException ex) {
            throw new IllegalArgumentException("Voucher date must use yyyy-MM-dd format");
        }
    }

    private String normalizePeriod(String period) {
        if (period == null || period.isBlank()) {
            return null;
        }
        var normalized = period.trim();
        if (!normalized.matches("\\d{4}-\\d{2}")) {
            throw new IllegalArgumentException("Period must use yyyy-MM format");
        }
        return normalized;
    }

    private String normalizeRequired(String value, String message) {
        if (value == null || value.trim().isEmpty()) {
            throw new IllegalArgumentException(message);
        }
        return value.trim();
    }

    private String normalizeEnum(String value, Set<String> supportedValues, String message) {
        var normalized = normalizeRequired(value, message).toUpperCase(Locale.ROOT);
        if (!supportedValues.contains(normalized)) {
            throw new IllegalArgumentException(message);
        }
        return normalized;
    }

    private BigDecimal normalizeAmount(BigDecimal value, String fieldName) {
        var amount = value == null ? ZERO : value.setScale(2, RoundingMode.HALF_UP);
        if (amount.compareTo(ZERO) < 0) {
            throw new IllegalArgumentException(fieldName + " cannot be negative");
        }
        return amount;
    }

    public record VoucherLineInput(
            String accountId,
            String summary,
            BigDecimal debitAmount,
            BigDecimal creditAmount
    ) {
    }

    private record PreparedVoucherLine(
            String id,
            int lineNo,
            String accountId,
            String accountCode,
            String accountName,
            String summary,
            BigDecimal debitAmount,
            BigDecimal creditAmount
    ) {
    }
}
