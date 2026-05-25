CREATE TABLE IF NOT EXISTS accounting_accounts (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    normal_balance TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE (workspace_id, code),
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id)
);

CREATE TABLE IF NOT EXISTS accounting_vouchers (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    voucher_no TEXT NOT NULL,
    voucher_date TEXT NOT NULL,
    period TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'DRAFT',
    description TEXT,
    created_by_user_id TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    posted_at TEXT,
    UNIQUE (workspace_id, voucher_no),
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
    FOREIGN KEY (created_by_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS accounting_voucher_lines (
    id TEXT PRIMARY KEY,
    voucher_id TEXT NOT NULL,
    line_no INTEGER NOT NULL,
    account_id TEXT NOT NULL,
    summary TEXT,
    debit_amount NUMERIC NOT NULL DEFAULT 0,
    credit_amount NUMERIC NOT NULL DEFAULT 0,
    FOREIGN KEY (voucher_id) REFERENCES accounting_vouchers(id),
    FOREIGN KEY (account_id) REFERENCES accounting_accounts(id)
);

CREATE INDEX IF NOT EXISTS idx_accounting_accounts_workspace_code
    ON accounting_accounts(workspace_id, code);

CREATE INDEX IF NOT EXISTS idx_accounting_vouchers_workspace_period
    ON accounting_vouchers(workspace_id, period, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_accounting_voucher_lines_voucher
    ON accounting_voucher_lines(voucher_id, line_no ASC);

CREATE INDEX IF NOT EXISTS idx_accounting_voucher_lines_account
    ON accounting_voucher_lines(account_id);
