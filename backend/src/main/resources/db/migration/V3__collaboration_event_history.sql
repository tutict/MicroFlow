CREATE TABLE IF NOT EXISTS collaboration_events (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    channel_id TEXT NOT NULL,
    collaboration_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    status TEXT NOT NULL,
    stage TEXT,
    agent_key TEXT,
    trigger_token TEXT,
    round INTEGER NOT NULL DEFAULT 0,
    max_rounds INTEGER NOT NULL DEFAULT 0,
    detail TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
    FOREIGN KEY (channel_id) REFERENCES channels(id)
);

CREATE INDEX IF NOT EXISTS idx_collaboration_events_channel_created
    ON collaboration_events(channel_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_collaboration_events_collaboration_created
    ON collaboration_events(collaboration_id, created_at ASC);
