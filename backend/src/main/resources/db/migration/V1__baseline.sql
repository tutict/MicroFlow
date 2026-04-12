CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    display_name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS workspaces (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    owner_user_id TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (owner_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS workspace_members (
    workspace_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    role TEXT NOT NULL,
    joined_at TEXT NOT NULL,
    PRIMARY KEY (workspace_id, user_id),
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS channels (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'ROOM',
    created_at TEXT NOT NULL,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id)
);

CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    channel_id TEXT NOT NULL,
    sender_type TEXT NOT NULL,
    sender_user_id TEXT,
    sender_agent_key TEXT,
    message_type TEXT NOT NULL DEFAULT 'TEXT',
    ciphertext BLOB NOT NULL,
    iv BLOB NOT NULL,
    auth_tag BLOB,
    key_version INTEGER NOT NULL,
    reply_to_message_id TEXT,
    created_at TEXT NOT NULL,
    edited_at TEXT,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
    FOREIGN KEY (channel_id) REFERENCES channels(id),
    FOREIGN KEY (sender_user_id) REFERENCES users(id),
    FOREIGN KEY (reply_to_message_id) REFERENCES messages(id)
);

CREATE TABLE IF NOT EXISTS message_mentions (
    id TEXT PRIMARY KEY,
    message_id TEXT NOT NULL,
    mention_type TEXT NOT NULL,
    target_ref TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (message_id) REFERENCES messages(id)
);

CREATE TABLE IF NOT EXISTS agent_configs (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    agent_key TEXT NOT NULL,
    provider TEXT NOT NULL,
    endpoint_url TEXT NOT NULL,
    credential_ciphertext BLOB NOT NULL,
    credential_iv BLOB NOT NULL,
    credential_key_version INTEGER NOT NULL,
    role_strategy TEXT,
    enabled INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE (workspace_id, agent_key),
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id)
);

CREATE TABLE IF NOT EXISTS agent_runs (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    channel_id TEXT NOT NULL,
    trigger_message_id TEXT NOT NULL,
    agent_key TEXT NOT NULL,
    provider TEXT NOT NULL,
    status TEXT NOT NULL,
    error_message TEXT,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    result_message_id TEXT,
    created_at TEXT NOT NULL,
    started_at TEXT,
    finished_at TEXT,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
    FOREIGN KEY (channel_id) REFERENCES channels(id),
    FOREIGN KEY (trigger_message_id) REFERENCES messages(id),
    FOREIGN KEY (result_message_id) REFERENCES messages(id)
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TEXT NOT NULL,
    revoked_at TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_workspace_members_user
    ON workspace_members(user_id);

CREATE INDEX IF NOT EXISTS idx_channels_workspace
    ON channels(workspace_id);

CREATE INDEX IF NOT EXISTS idx_messages_channel_created
    ON messages(channel_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_mentions_message
    ON message_mentions(message_id);

CREATE INDEX IF NOT EXISTS idx_agent_runs_status_created
    ON agent_runs(status, created_at);

CREATE INDEX IF NOT EXISTS idx_agent_runs_trigger_message
    ON agent_runs(trigger_message_id);
