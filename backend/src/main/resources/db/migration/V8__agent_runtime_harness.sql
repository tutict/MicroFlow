CREATE TABLE IF NOT EXISTS agent_run_sessions (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    task_id TEXT,
    channel_id TEXT,
    trigger_message_id TEXT,
    initiator_user_id TEXT NOT NULL,
    agent_key TEXT NOT NULL,
    run_kind TEXT NOT NULL,
    status TEXT NOT NULL,
    goal TEXT NOT NULL,
    context_summary TEXT,
    error_message TEXT,
    interruption_state TEXT NOT NULL DEFAULT 'NONE',
    resumed_from_session_id TEXT,
    step_count INTEGER NOT NULL DEFAULT 0,
    approval_wait_count INTEGER NOT NULL DEFAULT 0,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    started_at TEXT,
    finished_at TEXT,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id)
);

CREATE INDEX IF NOT EXISTS idx_agent_run_sessions_workspace_created
    ON agent_run_sessions(workspace_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_agent_run_sessions_status
    ON agent_run_sessions(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_agent_run_sessions_task
    ON agent_run_sessions(task_id, created_at DESC);

CREATE TABLE IF NOT EXISTS agent_run_events (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    workspace_id TEXT NOT NULL,
    seq INTEGER NOT NULL,
    event_type TEXT NOT NULL,
    payload_json TEXT,
    created_at TEXT NOT NULL,
    UNIQUE (session_id, seq),
    FOREIGN KEY (session_id) REFERENCES agent_run_sessions(id)
);

CREATE INDEX IF NOT EXISTS idx_agent_run_events_session_seq
    ON agent_run_events(session_id, seq ASC);

CREATE TABLE IF NOT EXISTS agent_run_steps (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    seq INTEGER NOT NULL,
    step_kind TEXT NOT NULL,
    status TEXT NOT NULL,
    agent_key TEXT,
    title TEXT NOT NULL,
    detail TEXT,
    started_at TEXT NOT NULL,
    finished_at TEXT,
    UNIQUE (session_id, seq),
    FOREIGN KEY (session_id) REFERENCES agent_run_sessions(id)
);

CREATE TABLE IF NOT EXISTS agent_run_messages (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    seq INTEGER NOT NULL,
    role TEXT NOT NULL,
    content TEXT,
    tool_calls_json TEXT,
    tool_call_id TEXT,
    created_at TEXT NOT NULL,
    UNIQUE (session_id, seq),
    FOREIGN KEY (session_id) REFERENCES agent_run_sessions(id)
);

CREATE TABLE IF NOT EXISTS agent_context_sources (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    workspace_id TEXT NOT NULL,
    source_type TEXT NOT NULL,
    ref_id TEXT,
    label TEXT NOT NULL,
    excerpt TEXT,
    included INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    FOREIGN KEY (session_id) REFERENCES agent_run_sessions(id)
);

CREATE INDEX IF NOT EXISTS idx_agent_context_sources_session
    ON agent_context_sources(session_id, created_at ASC);

CREATE TABLE IF NOT EXISTS agent_approvals (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    workspace_id TEXT NOT NULL,
    step_id TEXT,
    tool_key TEXT NOT NULL,
    action TEXT NOT NULL,
    target_resource TEXT,
    risk_level TEXT NOT NULL,
    impact_summary TEXT,
    input_json TEXT,
    status TEXT NOT NULL,
    decided_by_user_id TEXT,
    decision_note TEXT,
    created_at TEXT NOT NULL,
    decided_at TEXT,
    FOREIGN KEY (session_id) REFERENCES agent_run_sessions(id)
);

CREATE INDEX IF NOT EXISTS idx_agent_approvals_session_status
    ON agent_approvals(session_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS agent_artifacts (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    workspace_id TEXT NOT NULL,
    artifact_kind TEXT NOT NULL,
    title TEXT NOT NULL,
    summary TEXT,
    content_text TEXT,
    uri TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (session_id) REFERENCES agent_run_sessions(id)
);

CREATE INDEX IF NOT EXISTS idx_agent_artifacts_session
    ON agent_artifacts(session_id, created_at DESC);

CREATE TABLE IF NOT EXISTS agent_tool_invocations (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    workspace_id TEXT NOT NULL,
    step_id TEXT,
    tool_key TEXT NOT NULL,
    idempotency_key TEXT NOT NULL,
    status TEXT NOT NULL,
    risk_level TEXT NOT NULL,
    input_json TEXT,
    output_json TEXT,
    approval_id TEXT,
    error_message TEXT,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    finished_at TEXT,
    UNIQUE (session_id, idempotency_key),
    FOREIGN KEY (session_id) REFERENCES agent_run_sessions(id)
);

CREATE INDEX IF NOT EXISTS idx_agent_tool_invocations_session
    ON agent_tool_invocations(session_id, created_at ASC);

CREATE TABLE IF NOT EXISTS agent_provider_capabilities (
    workspace_id TEXT NOT NULL,
    agent_key TEXT NOT NULL,
    supports_tool_calls INTEGER NOT NULL,
    detail TEXT,
    detected_at TEXT NOT NULL,
    PRIMARY KEY (workspace_id, agent_key)
);

CREATE TABLE IF NOT EXISTS agent_connectors (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    owner_user_id TEXT NOT NULL,
    connector_kind TEXT NOT NULL,
    name TEXT NOT NULL,
    config_json TEXT NOT NULL,
    secret_ciphertext BLOB NOT NULL,
    secret_iv BLOB NOT NULL,
    secret_key_version INTEGER NOT NULL,
    sharing_scope TEXT NOT NULL,
    shared_user_ids TEXT,
    shared_agent_keys TEXT,
    status TEXT NOT NULL,
    last_error TEXT,
    last_checked_at TEXT,
    read_enabled INTEGER NOT NULL DEFAULT 1,
    write_enabled INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
    FOREIGN KEY (owner_user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_agent_connectors_workspace
    ON agent_connectors(workspace_id, connector_kind, created_at DESC);

CREATE TABLE IF NOT EXISTS agent_connector_grants (
    id TEXT PRIMARY KEY,
    connector_id TEXT NOT NULL,
    grantee_type TEXT NOT NULL,
    grantee_ref TEXT,
    created_at TEXT NOT NULL,
    UNIQUE (connector_id, grantee_type, grantee_ref),
    FOREIGN KEY (connector_id) REFERENCES agent_connectors(id)
);
