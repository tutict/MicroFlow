package com.microflow.agent.runtime.infrastructure.persistence;

import com.microflow.task.application.service.TaskRunStateLookup;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import com.microflow.common.jdbc.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcTaskRunStateLookup implements TaskRunStateLookup {
    private final JdbcTemplate jdbc;

    public JdbcTaskRunStateLookup(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public Map<String, State> statesForTasks(String workspaceId, List<String> taskIds) {
        if (taskIds.isEmpty()) return Map.of();
        var placeholders = String.join(",", Collections.nCopies(taskIds.size(), "?"));
        var sql = """
                SELECT task_id, MAX(CASE WHEN status = 'WAITING_APPROVAL' THEN 1 ELSE 0 END) AS waiting
                FROM agent_run_sessions
                WHERE workspace_id = ? AND task_id IN (%s)
                  AND status IN ('QUEUED', 'CONTEXT_BUILDING', 'RUNNING', 'WAITING_APPROVAL')
                GROUP BY task_id
                """.formatted(placeholders);
        var args = new ArrayList<Object>();
        args.add(workspaceId);
        args.addAll(taskIds);
        return jdbc.query(sql, result -> {
            var states = new LinkedHashMap<String, State>();
            while (result.next()) {
                states.put(result.getString("task_id"), result.getInt("waiting") == 1
                        ? State.WAITING_APPROVAL : State.RUNNING);
            }
            return Map.copyOf(states);
        }, args.toArray());
    }
}
