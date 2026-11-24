package com.microflow.task.infrastructure.persistence;

import com.microflow.task.domain.model.TaskActivity;
import com.microflow.task.domain.model.TaskItem;
import com.microflow.task.domain.model.TaskPriority;
import com.microflow.task.domain.model.TaskProject;
import com.microflow.task.domain.model.TaskStatus;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import com.microflow.common.jdbc.JdbcTemplate;
import com.microflow.common.jdbc.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcTaskRepository {

    private static final RowMapper<TaskItem> TASK_MAPPER = JdbcTaskRepository::mapTask;
    private static final RowMapper<TaskProject> PROJECT_MAPPER = JdbcTaskRepository::mapProject;
    private static final RowMapper<TaskActivity> ACTIVITY_MAPPER = JdbcTaskRepository::mapActivity;

    private static final String TASK_SELECT = """
            SELECT t.id, t.workspace_id, t.project_id, p.name AS project_name,
                   t.title, t.detail, t.status, t.priority,
                   t.assignee_user_id, assignee.display_name AS assignee_display_name,
                   t.creator_user_id, t.origin_channel_id, t.origin_message_id,
                   t.due_at, t.created_at, t.updated_at, t.completed_at
            FROM tasks t
            LEFT JOIN task_projects p ON p.id = t.project_id
            LEFT JOIN users assignee ON assignee.id = t.assignee_user_id
            """;

    private final JdbcTemplate jdbcTemplate;
    private final Clock clock;

    public JdbcTaskRepository(JdbcTemplate jdbcTemplate, Clock clock) {
        this.jdbcTemplate = jdbcTemplate;
        this.clock = clock;
    }

    public List<TaskProject> findProjects(String workspaceId) {
        return jdbcTemplate.query("""
                SELECT p.id, p.workspace_id, p.name, p.description, p.status, p.created_by_user_id,
                       COUNT(t.id) AS task_count,
                       COALESCE(SUM(CASE WHEN t.status IN ('OPEN', 'IN_PROGRESS', 'BLOCKED') THEN 1 ELSE 0 END), 0)
                           AS open_task_count
                FROM task_projects p
                LEFT JOIN tasks t ON t.project_id = p.id
                WHERE p.workspace_id = ?
                GROUP BY p.id, p.workspace_id, p.name, p.description, p.status,
                         p.created_by_user_id, p.created_at
                ORDER BY p.created_at ASC
                """, PROJECT_MAPPER, workspaceId);
    }

    public String createProject(String workspaceId, String name, String description, String creatorUserId) {
        var projectId = "proj_" + UUID.randomUUID();
        var now = Instant.now(clock).toString();
        jdbcTemplate.update("""
                INSERT INTO task_projects(id, workspace_id, name, description, status,
                                          created_by_user_id, created_at, updated_at)
                VALUES (?, ?, ?, ?, 'ACTIVE', ?, ?, ?)
                """, projectId, workspaceId, name, description, creatorUserId, now, now);
        return projectId;
    }

    public boolean projectExists(String workspaceId, String projectId) {
        if (projectId == null || projectId.isBlank()) {
            return true;
        }
        Integer count = jdbcTemplate.queryForObject("""
                SELECT COUNT(1) FROM task_projects WHERE workspace_id = ? AND id = ?
                """, Integer.class, workspaceId, projectId);
        return count != null && count > 0;
    }

    public List<TaskItem> findTasks(
            String workspaceId,
            String projectId,
            TaskStatus statusFilter,
            String assigneeUserId,
            boolean unassignedOnly,
            int limit
    ) {
        var sql = new StringBuilder(TASK_SELECT).append(" WHERE t.workspace_id = ?");
        var params = new java.util.ArrayList<Object>();
        params.add(workspaceId);
        if (projectId != null && !projectId.isBlank()) {
            sql.append(" AND t.project_id = ?");
            params.add(projectId);
        }
        if (statusFilter != null) {
            sql.append(" AND t.status = ?");
            params.add(statusFilter.storedValue());
        }
        if (unassignedOnly) {
            sql.append(" AND t.assignee_user_id IS NULL");
        }
        if (assigneeUserId != null && !assigneeUserId.isBlank()) {
            sql.append(" AND t.assignee_user_id = ?");
            params.add(assigneeUserId);
        }
        sql.append(" ORDER BY t.created_at DESC LIMIT ?");
        params.add(limit);
        return jdbcTemplate.query(sql.toString(), TASK_MAPPER, params.toArray());
    }

    /**
     * Finds unassigned tasks a given user created. The creator and assignee
     * predicates live in SQL on purpose: filtering creator in memory after a
     * window-wide {@code LIMIT} silently drops older work once a workspace grows
     * past the limit.
     */
    public List<TaskItem> findUnassignedCreatedBy(String workspaceId, String creatorUserId, int limit) {
        return jdbcTemplate.query(
                TASK_SELECT + " WHERE t.workspace_id = ?"
                        + " AND t.creator_user_id = ?"
                        + " AND t.assignee_user_id IS NULL"
                        + " ORDER BY t.created_at DESC LIMIT ?",
                TASK_MAPPER, workspaceId, creatorUserId, limit);
    }

    public Optional<TaskItem> findTask(String workspaceId, String taskId) {
        return jdbcTemplate.query(
                TASK_SELECT + " WHERE t.workspace_id = ? AND t.id = ?",
                TASK_MAPPER, workspaceId, taskId
        ).stream().findFirst();
    }

    public Optional<String> findAssignee(String workspaceId, String taskId) {
        return jdbcTemplate.query(
                "SELECT assignee_user_id FROM tasks WHERE workspace_id = ? AND id = ?",
                (rs, rowNum) -> rs.getString("assignee_user_id"), workspaceId, taskId
        ).stream().findFirst();
    }

    public Optional<AccountableUsers> findAccountableUsers(String workspaceId, String taskId) {
        return jdbcTemplate.query("""
                SELECT assignee_user_id, creator_user_id
                FROM tasks
                WHERE workspace_id = ? AND id = ?
                """,
                (rs, rowNum) -> new AccountableUsers(
                        rs.getString("assignee_user_id"), rs.getString("creator_user_id")),
                workspaceId, taskId
        ).stream().findFirst();
    }

    public record AccountableUsers(String assigneeUserId, String creatorUserId) {
    }

    public String createTask(
            String workspaceId,
            String projectId,
            String title,
            String detail,
            TaskStatus status,
            TaskPriority priority,
            String assigneeUserId,
            String creatorUserId,
            String originChannelId,
            String originMessageId,
            Instant dueAt
    ) {
        var taskId = "task_" + UUID.randomUUID();
        var now = Instant.now(clock);
        jdbcTemplate.update("""
                INSERT INTO tasks(id, workspace_id, project_id, title, detail, status, priority,
                                  assignee_user_id, creator_user_id, origin_channel_id, origin_message_id,
                                  due_at, created_at, updated_at, completed_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                taskId, workspaceId, projectId, title, detail, status.storedValue(), priority.storedValue(),
                assigneeUserId, creatorUserId, originChannelId, originMessageId,
                dueAt == null ? null : dueAt.toString(),
                now.toString(), now.toString(),
                status == TaskStatus.DONE ? now.toString() : null);
        return taskId;
    }

    /**
     * Applies a status transition guarded by the status it expects to replace.
     *
     * @return true when exactly one row moved; false means another writer already
     *     changed the status, so the caller must not record an activity for a
     *     transition that did not happen
     */
    public boolean applyStatus(String taskId, TaskStatus from, TaskStatus to) {
        var now = Instant.now(clock).toString();
        return jdbcTemplate.update("""
                UPDATE tasks
                SET status = ?,
                    updated_at = ?,
                    completed_at = CASE WHEN ? = 'DONE' THEN ? ELSE NULL END
                WHERE id = ? AND status = ?
                """, to.storedValue(), now, to.storedValue(), now, taskId, from.storedValue()) > 0;
    }

    public void applyAssignee(String taskId, String assigneeUserId) {
        jdbcTemplate.update(
                "UPDATE tasks SET assignee_user_id = ?, updated_at = ? WHERE id = ?",
                assigneeUserId, Instant.now(clock).toString(), taskId
        );
    }

    public void recordActivity(
            String taskId,
            String workspaceId,
            String actorUserId,
            String eventType,
            String fromValue,
            String toValue,
            String note
    ) {
        jdbcTemplate.update("""
                INSERT INTO task_activity(id, task_id, workspace_id, actor_user_id, event_type,
                                          from_value, to_value, note, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, "act_" + UUID.randomUUID(), taskId, workspaceId, actorUserId, eventType,
                fromValue, toValue, note, Instant.now(clock).toString());
    }

    public List<TaskActivity> findActivity(String workspaceId, String taskId, int limit) {
        return jdbcTemplate.query("""
                SELECT a.id, a.task_id, a.workspace_id, a.actor_user_id,
                       u.display_name AS actor_display_name,
                       a.event_type, a.from_value, a.to_value, a.note, a.created_at
                FROM task_activity a
                JOIN users u ON u.id = a.actor_user_id
                WHERE a.workspace_id = ? AND a.task_id = ?
                ORDER BY a.created_at ASC
                LIMIT ?
                """, ACTIVITY_MAPPER, workspaceId, taskId, limit);
    }

    /** Latest entries for the run prompt; the history API retains its ascending order. */
    public List<TaskActivity> findRecentActivity(String workspaceId, String taskId, int limit) {
        return jdbcTemplate.query("""
                SELECT a.id, a.task_id, a.workspace_id, a.actor_user_id,
                       u.display_name AS actor_display_name,
                       a.event_type, a.from_value, a.to_value, a.note, a.created_at
                FROM task_activity a
                JOIN users u ON u.id = a.actor_user_id
                WHERE a.workspace_id = ? AND a.task_id = ?
                ORDER BY a.created_at DESC, a.id DESC
                LIMIT ?
                """, ACTIVITY_MAPPER, workspaceId, taskId, Math.max(1, limit));
    }

    public boolean channelExists(String workspaceId, String channelId) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT COUNT(1) FROM channels WHERE workspace_id = ? AND id = ?
                """, Integer.class, workspaceId, channelId);
        return count != null && count > 0;
    }

    /** Mirrors {@link #channelExists} so a task cannot cite another workspace's message. */
    public boolean messageExists(String workspaceId, String messageId) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT COUNT(1) FROM messages WHERE workspace_id = ? AND id = ?
                """, Integer.class, workspaceId, messageId);
        return count != null && count > 0;
    }

    public long countByStatus(String workspaceId, String projectId, String status) {
        var sql = new StringBuilder(
                "SELECT COUNT(1) FROM tasks WHERE workspace_id = ? AND status = ?");
        var params = new java.util.ArrayList<Object>();
        params.add(workspaceId);
        params.add(status);
        if (projectId != null && !projectId.isBlank()) {
            sql.append(" AND project_id = ?");
            params.add(projectId);
        }
        Integer count = jdbcTemplate.queryForObject(sql.toString(), Integer.class, params.toArray());
        return count == null ? 0L : count.longValue();
    }

    private static TaskItem mapTask(ResultSet rs, int rowNum) throws SQLException {
        return new TaskItem(
                rs.getString("id"),
                rs.getString("workspace_id"),
                rs.getString("project_id"),
                rs.getString("project_name"),
                rs.getString("title"),
                rs.getString("detail"),
                TaskStatus.fromStored(rs.getString("status")),
                TaskPriority.fromStored(rs.getString("priority")),
                rs.getString("assignee_user_id"),
                rs.getString("assignee_display_name"),
                rs.getString("creator_user_id"),
                rs.getString("origin_channel_id"),
                rs.getString("origin_message_id"),
                parseInstant(rs.getString("due_at")),
                parseInstant(rs.getString("created_at")),
                parseInstant(rs.getString("updated_at")),
                parseInstant(rs.getString("completed_at"))
        );
    }

    private static TaskProject mapProject(ResultSet rs, int rowNum) throws SQLException {
        return new TaskProject(
                rs.getString("id"),
                rs.getString("workspace_id"),
                rs.getString("name"),
                rs.getString("description"),
                rs.getString("status"),
                rs.getString("created_by_user_id"),
                rs.getLong("task_count"),
                rs.getLong("open_task_count")
        );
    }

    private static TaskActivity mapActivity(ResultSet rs, int rowNum) throws SQLException {
        return new TaskActivity(
                rs.getString("id"),
                rs.getString("task_id"),
                rs.getString("workspace_id"),
                rs.getString("actor_user_id"),
                rs.getString("actor_display_name"),
                rs.getString("event_type"),
                rs.getString("from_value"),
                rs.getString("to_value"),
                rs.getString("note"),
                parseInstant(rs.getString("created_at"))
        );
    }

    private static Instant parseInstant(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        try {
            return Instant.parse(value);
        } catch (RuntimeException ignored) {
            return null;
        }
    }
}
