package com.microflow.agent.runtime.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.microflow.agent.runtime.domain.model.AgentRunSession;
import com.microflow.agent.runtime.domain.model.AgentRunStatus;
import com.microflow.chat.infrastructure.persistence.JdbcMessageRepository;
import com.microflow.knowledge.application.service.KnowledgeBaseService;
import com.microflow.knowledge.domain.model.KnowledgeChunk;
import com.microflow.knowledge.infrastructure.persistence.JdbcKnowledgeRepository;
import com.microflow.realtime.broadcaster.RealtimeBroadcaster;
import com.microflow.task.infrastructure.persistence.JdbcTaskDecisionRepository;
import com.microflow.task.infrastructure.persistence.JdbcTaskRepository;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import com.microflow.common.jdbc.JdbcTemplate;
import org.sqlite.SQLiteDataSource;

class AgentContextSourceRepairTest {
    @TempDir Path directory;
    private final Clock clock = Clock.fixed(Instant.parse("2026-11-24T00:00:00Z"), ZoneOffset.UTC);
    private JdbcTemplate jdbc;
    private JdbcTaskRepository tasks;
    private JdbcTaskDecisionRepository decisions;
    private final JdbcKnowledgeRepository knowledge = mock(JdbcKnowledgeRepository.class);

    @BeforeEach
    void initialize() {
        var dataSource = new SQLiteDataSource();
        dataSource.setUrl("jdbc:sqlite:" + directory.resolve("context.db"));
        jdbc = new JdbcTemplate(dataSource);
        // Real SQL sorting with just the tables needed by this read-only fixture.
        jdbc.execute("CREATE TABLE users (id TEXT PRIMARY KEY, display_name TEXT)");
        jdbc.execute("CREATE TABLE task_decisions (id TEXT, workspace_id TEXT, task_id TEXT, sequence_no INTEGER, "
                + "supersedes_decision_id TEXT, summary TEXT, rationale TEXT, alternatives_considered TEXT, "
                + "decided_by_user_id TEXT, created_at TEXT)");
        jdbc.execute("CREATE TABLE task_activity (id TEXT, task_id TEXT, workspace_id TEXT, actor_user_id TEXT, "
                + "event_type TEXT, from_value TEXT, to_value TEXT, note TEXT, created_at TEXT)");
        jdbc.update("INSERT INTO users VALUES ('usr_fixture', 'Fixture')");
        tasks = new JdbcTaskRepository(jdbc, clock);
        decisions = new JdbcTaskDecisionRepository(jdbc, clock);
        when(knowledge.listChunks("ws_fixture", 80)).thenReturn(List.of());
    }

    @Test
    void recentDecisionSourcesContainNewestThreeOfFourDescendingRecords() {
        for (var index = 1; index <= 4; index++) {
            jdbc.update("INSERT INTO task_decisions (id, workspace_id, task_id, sequence_no, summary, "
                    + "decided_by_user_id, created_at) VALUES (?, 'ws_fixture', 'task_fixture', ?, ?, 'usr_fixture', ?)",
                    "dec_" + index, index, "decision-" + index, clock.instant().toString());
        }
        var context = builderForTask().build(session("task_fixture"));
        assertThat(context.sources()).filteredOn(source -> source.sourceType().equals("DECISION"))
                .extracting(source -> source.refId()).containsExactly("dec_4", "dec_3", "dec_2");
        assertThat(context.block()).contains("decision-4", "decision-3", "decision-2").doesNotContain("decision-1");
    }

    @Test
    void recentActivitySourcesContainNewestFiveWhileHistoryRetainsOldestFirst() {
        for (var index = 1; index <= 6; index++) {
            jdbc.update("INSERT INTO task_activity VALUES (?, 'task_fixture', 'ws_fixture', 'usr_fixture', "
                    + "'NOTE', NULL, NULL, ?, ?)", "act_" + index, "activity-" + index,
                    "2026-11-23T00:00:0" + index + "Z");
        }
        assertThat(tasks.findActivity("ws_fixture", "task_fixture", 5))
                .extracting(value -> value.id()).containsExactly("act_1", "act_2", "act_3", "act_4", "act_5");
        var context = builderForTask().build(session("task_fixture"));
        assertThat(context.sources()).filteredOn(source -> source.sourceType().equals("ACTIVITY"))
                .extracting(source -> source.refId()).containsExactly("act_6", "act_5", "act_4", "act_3", "act_2");
        assertThat(context.block()).contains("activity-6").doesNotContain("activity-1");
    }

    @Test
    void knowledgeReferencesAndExcerptsAreExactlyTheRankedPromptSnippetsFromOneRead() {
        var matching = List.of(
                chunk("doc_best", "rollout.md", "rollout checklist selected slice", "2026-11-24T00:00:00Z"),
                chunk("doc_second", "runbook.md", "rollout fallback selected slice", "2026-11-24T00:00:00Z"),
                chunk("doc_unused", "unrelated.md", "unrelated omitted slice", "2020-01-01T00:00:00Z"));
        // A second retrieval would observe different rows: sources must use the prompt's own retrieval.
        when(knowledge.listChunks("ws_fixture", 80)).thenReturn(matching, List.of(
                chunk("doc_later", "changed.md", "rollout changed after retrieval", "2026-11-24T00:00:00Z")));
        var builder = new AgentContextBuilder(tasks, decisions, mock(JdbcMessageRepository.class), knowledgeService(), clock);
        var context = builder.build(session(null));
        var sources = context.sources().stream().filter(value -> value.sourceType().equals("KNOWLEDGE")).toList();
        assertThat(sources).extracting(value -> value.refId()).containsExactly("doc_best", "doc_second");
        assertThat(sources).extracting(value -> value.label()).containsExactly("rollout.md", "runbook.md");
        assertThat(sources).extracting(value -> value.excerpt())
                .containsExactly("rollout checklist selected slice", "rollout fallback selected slice");
        assertThat(context.block()).contains("[kb:doc_best] rollout.md: rollout checklist selected slice",
                "[kb:doc_second] runbook.md: rollout fallback selected slice")
                .doesNotContain("doc_unused", "doc_later", "unrelated omitted slice");
    }

    private AgentContextBuilder builderForTask() {
        var taskReads = org.mockito.Mockito.spy(tasks);
        org.mockito.Mockito.doReturn(java.util.Optional.empty()).when(taskReads).findTask("ws_fixture", "task_fixture");
        return new AgentContextBuilder(taskReads, decisions, mock(JdbcMessageRepository.class), knowledgeService(), clock);
    }

    private KnowledgeBaseService knowledgeService() {
        return new KnowledgeBaseService(knowledge, mock(JdbcWorkspaceRepository.class), mock(JdbcMessageRepository.class),
                mock(RealtimeBroadcaster.class), clock, directory.toString(), 1024, 2);
    }

    private KnowledgeChunk chunk(String id, String name, String text, String createdAt) {
        return new KnowledgeChunk(id, name, null, text, 0, createdAt, createdAt);
    }

    private AgentRunSession session(String taskId) {
        return new AgentRunSession("run_fixture", "ws_fixture", taskId, null, null, "usr_fixture", "assistant",
                "TASK", AgentRunStatus.CONTEXT_BUILDING, "rollout", null, null, "NONE", null, 0, 0, 0,
                clock.instant().toString(), null, null, clock.instant().toString());
    }
}
