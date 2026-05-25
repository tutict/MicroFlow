package com.microflow.accounting.api.rest;

import com.microflow.accounting.api.dto.AccountingAccountResponse;
import com.microflow.accounting.api.dto.AccountingVoucherResponse;
import com.microflow.accounting.api.dto.CreateAccountingAccountRequest;
import com.microflow.accounting.api.dto.CreateAccountingVoucherRequest;
import com.microflow.accounting.api.dto.TrialBalanceRowResponse;
import com.microflow.accounting.api.mapper.AccountingApiMapper;
import com.microflow.accounting.application.service.AccountingService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/workspaces/{workspaceId}/accounting")
public class AccountingController {

    private final AccountingService accountingService;
    private final AccountingApiMapper accountingApiMapper;

    public AccountingController(
            AccountingService accountingService,
            AccountingApiMapper accountingApiMapper
    ) {
        this.accountingService = accountingService;
        this.accountingApiMapper = accountingApiMapper;
    }

    @GetMapping("/accounts")
    public List<AccountingAccountResponse> listAccounts(
            @PathVariable String workspaceId,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return accountingService.listAccounts(workspaceId, userId).stream()
                .map(accountingApiMapper::toResponse)
                .toList();
    }

    @PostMapping("/accounts")
    public AccountingAccountResponse createAccount(
            @PathVariable String workspaceId,
            @Valid @RequestBody CreateAccountingAccountRequest request,
            HttpServletRequest httpRequest
    ) {
        var userId = (String) httpRequest.getAttribute("currentUserId");
        return accountingApiMapper.toResponse(accountingService.createAccount(
                workspaceId,
                userId,
                request.code(),
                request.name(),
                request.category(),
                request.normalBalance()
        ));
    }

    @GetMapping("/vouchers")
    public List<AccountingVoucherResponse> listVouchers(
            @PathVariable String workspaceId,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return accountingService.listVouchers(workspaceId, userId).stream()
                .map(accountingApiMapper::toResponse)
                .toList();
    }

    @PostMapping("/vouchers")
    public AccountingVoucherResponse createVoucher(
            @PathVariable String workspaceId,
            @Valid @RequestBody CreateAccountingVoucherRequest request,
            HttpServletRequest httpRequest
    ) {
        var userId = (String) httpRequest.getAttribute("currentUserId");
        var lines = request.lines().stream()
                .map(line -> new AccountingService.VoucherLineInput(
                        line.accountId(),
                        line.summary(),
                        line.debitAmount(),
                        line.creditAmount()
                ))
                .toList();
        return accountingApiMapper.toResponse(accountingService.createVoucher(
                workspaceId,
                userId,
                request.voucherDate(),
                request.description(),
                lines
        ));
    }

    @PostMapping("/vouchers/{voucherId}/post")
    public AccountingVoucherResponse postVoucher(
            @PathVariable String workspaceId,
            @PathVariable String voucherId,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return accountingApiMapper.toResponse(accountingService.postVoucher(workspaceId, userId, voucherId));
    }

    @GetMapping("/trial-balance")
    public List<TrialBalanceRowResponse> trialBalance(
            @PathVariable String workspaceId,
            @RequestParam(required = false) String period,
            HttpServletRequest request
    ) {
        var userId = (String) request.getAttribute("currentUserId");
        return accountingService.trialBalance(workspaceId, userId, period).stream()
                .map(accountingApiMapper::toResponse)
                .toList();
    }
}
