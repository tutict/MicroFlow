CREATE TABLE IF NOT EXISTS task_projects (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    created_by_user_id TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
    FOREIGN KEY (created_by_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS tasks (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    project_id TEXT,
    title TEXT NOT NULL,
    detail TEXT,
    status TEXT NOT NULL DEFAULT 'OPEN',
    priority TEXT NOT NULL DEFAULT 'NORMAL',
    assignee_user_id TEXT,
    creator_user_id TEXT NOT NULL,
    origin_channel_id TEXT,
    origin_message_id TEXT,
    due_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    completed_at TEXT,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
    FOREIGN KEY (project_id) REFERENCES task_projects(id),
    FOREIGN KEY (assignee_user_id) REFERENCES users(id),
    FOREIGN KEY (creator_user_id) REFERENCES users(id),
    FOREIGN KEY (origin_channel_id) REFERENCES channels(id),
    FOREIGN KEY (origin_message_id) REFERENCES messages(id)
);

CREATE TABLE IF NOT EXISTS task_activity (
    id TEXT PRIMARY KEY,
    task_id TEXT NOT NULL,
    workspace_id TEXT NOT NULL,
    actor_user_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    from_value TEXT,
    to_value TEXT,
    note TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (task_id) REFERENCES tasks(id),
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
    FOREIGN KEY (actor_user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_task_projects_workspace
    ON task_projects(workspace_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_tasks_workspace_status
    ON tasks(workspace_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_tasks_project
    ON tasks(project_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_tasks_assignee_status
    ON tasks(workspace_id, assignee_user_id, status);

CREATE INDEX IF NOT EXISTS idx_tasks_due_at
    ON tasks(workspace_id, due_at);

CREATE INDEX IF NOT EXISTS idx_task_activity_task
    ON task_activity(task_id, created_at ASC);
