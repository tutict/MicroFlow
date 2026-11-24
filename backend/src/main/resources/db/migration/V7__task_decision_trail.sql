CREATE TABLE IF NOT EXISTS task_decisions (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    task_id TEXT NOT NULL,
    sequence_no INTEGER NOT NULL,
    supersedes_decision_id TEXT,
    summary TEXT NOT NULL,
    rationale TEXT,
    alternatives_considered TEXT,
    decided_by_user_id TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
    FOREIGN KEY (task_id) REFERENCES tasks(id),
    FOREIGN KEY (supersedes_decision_id) REFERENCES task_decisions(id),
    FOREIGN KEY (decided_by_user_id) REFERENCES users(id),
    UNIQUE (task_id, sequence_no)
);

CREATE INDEX IF NOT EXISTS idx_task_decisions_task
    ON task_decisions(task_id, sequence_no DESC);

CREATE INDEX IF NOT EXISTS idx_task_decisions_workspace_created
    ON task_decisions(workspace_id, created_at DESC);
