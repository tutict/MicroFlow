package com.microflow.agent.runtime.application;

import com.microflow.agent.runtime.domain.model.AgentContextSource;
import com.microflow.agent.runtime.domain.model.AgentRunSession;
import com.microflow.chat.infrastructure.persistence.JdbcMessageRepository;
import com.microflow.knowledge.application.service.KnowledgeBaseService;
import com.microflow.task.infrastructure.persistence.JdbcTaskDecisionRepository;
import com.microflow.task.infrastructure.persistence.JdbcTaskRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;

/**
 * Assembles what the agent actually sees before a run starts.
 *
 * <p>The output is two things the user can inspect: a prompt block, and the list
 * of sources that produced it. Storing the list (references and short excerpts
 * only) is what makes "why did it answer that" answerable after the fact without
 * duplicating the underlying mailbox or file tree.
 */
@Service
public class AgentContextBuilder {

    private static final int MAX_EXCERPT = 240;

    private final JdbcTaskRepository taskRepository;
    private final JdbcTaskDecisionRepository decisionRepository;
    private final JdbcMessageRepository messageRepository;
    private final KnowledgeBaseService knowledgeBaseService;
    private final Clock clock;

    public AgentContextBuilder(
            JdbcTaskRepository taskRepository,
            JdbcTaskDecisionRepository decisionRepository,
            JdbcMessageRepository messageRepository,
            KnowledgeBaseService knowledgeBaseService,
            Clock clock
    ) {
        this.taskRepository = taskRepository;
        this.decisionRepository = decisionRepository;
        this.messageRepository = messageRepository;
        this.knowledgeBaseService = knowledgeBaseService;
        this.clock = clock;
    }

    public RunContext build(AgentRunSession session) {
        var now = Instant.now(clock).toString();
        var sources = new ArrayList<AgentContextSource>();
        var block = new StringBuilder();

        if (session.taskId() != null && !session.taskId().isBlank()) {
            taskRepository.findTask(session.workspaceId(), session.taskId()).ifPresent(task -> {
                block.append("Task: ").append(task.title())
                        .append(" [").append(task.status().storedValue())
                        .append(", ").append(task.priority().storedValue()).append("]\n");
                if (task.detail() != null && !task.detail().isBlank()) {
                    block.append("Task detail: ").append(truncate(task.detail(), 400)).append('\n');
                }
                if (task.assigneeDisplayName() != null) {
                    block.append("Assignee: ").append(task.assigneeDisplayName()).append('\n');
                }
                sources.add(source(session, "TASK", task.id(), "Task: " + task.title(),
                        truncate(task.detail() == null ? task.title() : task.detail(), MAX_EXCERPT), now));
                if (task.projectName() != null && !task.projectName().isBlank()) {
                    block.append("Project: ").append(task.projectName()).append('\n');
                    sources.add(source(session, "PROJECT", task.projectId(),
                            "Project: " + task.projectName(), null, now));
                }
            });

            var decisions = decisionRepository.findByTask(session.workspaceId(), session.taskId());
            if (!decisions.isEmpty()) {
                block.append("\nRecent decisions:\n");
                var recent = decisions.stream()
                        .limit(3)
                        .toList();
                for (var decision : recent) {
                    block.append("- #").append(decision.sequenceNo()).append(' ')
                            .append(decision.summary());
                    if (decision.rationale() != null && !decision.rationale().isBlank()) {
                        block.append(" (reason: ").append(truncate(decision.rationale(), 160)).append(')');
                    }
                    block.append('\n');
                    sources.add(source(session, "DECISION", decision.id(),
                            "Decision #" + decision.sequenceNo(), decision.summary(), now));
                }
            }

            var activity = taskRepository.findRecentActivity(session.workspaceId(), session.taskId(), 5);
            if (!activity.isEmpty()) {
                block.append("\nRecent activity:\n");
                for (var entry : activity) {
                    block.append("- ").append(entry.eventType());
                    if (entry.fromValue() != null || entry.toValue() != null) {
                        block.append(" (").append(entry.fromValue()).append(" -> ")
                                .append(entry.toValue()).append(')');
                    }
                    if (entry.note() != null && !entry.note().isBlank()) {
                        block.append(": ").append(truncate(entry.note(), 120));
                    }
                    block.append('\n');
                    sources.add(source(session, "ACTIVITY", entry.id(),
                            "Activity: " + entry.eventType(), entry.note(), now));
                }
            }
        }

        if (session.channelId() != null && !session.channelId().isBlank()) {
            var messages = messageRepository.findByChannel(session.channelId(), 12);
            if (!messages.isEmpty()) {
                block.append("\nRecent channel messages:\n");
                for (var message : messages) {
                    var speaker = message.senderUserId() == null ? "system" : message.senderUserId();
                    block.append("- ").append(speaker).append(": ")
                            .append(truncate(message.content(), 200)).append('\n');
                    sources.add(source(session, "MESSAGE", message.id(),
                            "Message " + message.id(), truncate(message.content(), MAX_EXCERPT), now));
                }
            }
        }

        var knowledgeContext = knowledgeBaseService.retrieveContext(
                session.workspaceId(), session.channelId(), session.goal());
        if (!knowledgeContext.block().isBlank()) {
            block.append('\n').append(knowledgeContext.block()).append('\n');
            for (var snippet : knowledgeContext.snippets()) {
                sources.add(source(session, "KNOWLEDGE", snippet.documentId(), snippet.fileName(),
                        truncate(snippet.content(), MAX_EXCERPT), now));
            }
        }

        var summary = summarize(sources);
        return new RunContext(block.toString().trim(), List.copyOf(sources), summary);
    }

    private AgentContextSource source(
            AgentRunSession session,
            String type,
            String refId,
            String label,
            String excerpt,
            String now
    ) {
        return new AgentContextSource(
                "ctx_" + UUID.randomUUID(),
                session.id(),
                session.workspaceId(),
                type,
                refId,
                label,
                excerpt,
                true,
                now
        );
    }

    private String summarize(List<AgentContextSource> sources) {
        if (sources.isEmpty()) {
            return "No workspace context matched this run.";
        }
        var counts = new java.util.LinkedHashMap<String, Integer>();
        for (var source : sources) {
            counts.merge(source.sourceType(), 1, Integer::sum);
        }
        var parts = counts.entrySet().stream()
                .map(entry -> entry.getValue() + " " + entry.getKey().toLowerCase(java.util.Locale.ROOT))
                .toList();
        return "Context: " + String.join(", ", parts);
    }

    private String truncate(String value, int maxLength) {
        if (value == null) {
            return null;
        }
        var normalized = value.replaceAll("\\s+", " ").trim();
        return normalized.length() <= maxLength
                ? normalized
                : normalized.substring(0, maxLength) + "...";
    }

    /** Prompt block plus the auditable source list. */
    public record RunContext(String block, List<AgentContextSource> sources, String summary) {
    }
}
