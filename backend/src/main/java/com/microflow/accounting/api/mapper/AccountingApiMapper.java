package com.microflow.accounting.api.mapper;

import com.microflow.accounting.api.dto.AccountingAccountResponse;
import com.microflow.accounting.api.dto.AccountingVoucherLineResponse;
import com.microflow.accounting.api.dto.AccountingVoucherResponse;
import com.microflow.accounting.api.dto.TrialBalanceRowResponse;
import com.microflow.accounting.domain.model.AccountingAccount;
import com.microflow.accounting.domain.model.AccountingVoucher;
import com.microflow.accounting.domain.model.AccountingVoucherLine;
import com.microflow.accounting.domain.model.TrialBalanceRow;
import org.springframework.stereotype.Component;

@Component
public class AccountingApiMapper {

    public AccountingAccountResponse toResponse(AccountingAccount account) {
        return new AccountingAccountResponse(
                account.id(),
                account.workspaceId(),
                account.code(),
                account.name(),
                account.category(),
                account.normalBalance(),
                account.active(),
                account.createdAt(),
                account.updatedAt()
        );
    }

    public AccountingVoucherResponse toResponse(AccountingVoucher voucher) {
        return new AccountingVoucherResponse(
                voucher.id(),
                voucher.workspaceId(),
                voucher.voucherNo(),
                voucher.voucherDate(),
                voucher.period(),
                voucher.status(),
                voucher.description(),
                voucher.totalDebit(),
                voucher.totalCredit(),
                voucher.createdByUserId(),
                voucher.createdAt(),
                voucher.updatedAt(),
                voucher.postedAt(),
                voucher.lines().stream().map(this::toResponse).toList()
        );
    }

    public AccountingVoucherLineResponse toResponse(AccountingVoucherLine line) {
        return new AccountingVoucherLineResponse(
                line.id(),
                line.voucherId(),
                line.lineNo(),
                line.accountId(),
                line.accountCode(),
                line.accountName(),
                line.summary(),
                line.debitAmount(),
                line.creditAmount()
        );
    }

    public TrialBalanceRowResponse toResponse(TrialBalanceRow row) {
        return new TrialBalanceRowResponse(
                row.accountId(),
                row.accountCode(),
                row.accountName(),
                row.category(),
                row.normalBalance(),
                row.debitAmount(),
                row.creditAmount(),
                row.balanceAmount(),
                row.balanceDirection()
        );
    }
}
