package com.microflow.agent.runtime.infrastructure.tool;

import com.microflow.agent.runtime.domain.model.ToolDescriptor;
import com.microflow.agent.runtime.domain.model.ToolPolicy;
import com.microflow.agent.runtime.domain.tool.AgentTool;
import com.microflow.agent.runtime.domain.tool.ToolContext;
import com.microflow.agent.runtime.domain.tool.ToolInputs;
import com.microflow.agent.runtime.domain.tool.ToolResult;
import com.microflow.knowledge.application.service.KnowledgeBaseService;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Component;

/** Read-only retrieval over the workspace knowledge base. */
@Component
public class KnowledgeSearchTool implements AgentTool {

    private final KnowledgeBaseService knowledgeBaseService;

    public KnowledgeSearchTool(KnowledgeBaseService knowledgeBaseService) {
        this.knowledgeBaseService = knowledgeBaseService;
    }

    @Override
    public ToolDescriptor descriptor() {
        return new ToolDescriptor(
                "knowledge.search",
                "Search workspace knowledge",
                "Retrieves the most relevant uploaded workspace documents for a query. Read-only.",
                Map.of(
                        "type", "object",
                        "properties", Map.of(
                                "query", Map.of("type", "string", "description", "what to look for"),
                                "limit", Map.of("type", "integer", "minimum", 1, "maximum", 10)
                        ),
                        "required", List.of("query")
                ),
                ToolPolicy.Permission.AUTO,
                ToolPolicy.Risk.READ_ONLY,
                true,
                null
        );
    }

    @Override
    public ToolResult invoke(ToolContext context, Map<String, Object> input) {
        var query = ToolInputs.requiredString(input, "query");
        var limit = ToolInputs.optionalInt(input, "limit", 3, 1, 10);
        var snippets = knowledgeBaseService.searchSnippets(
                context.workspaceId(), context.channelId(), query, limit);
        var payload = new LinkedHashMap<String, Object>();
        payload.put("query", query);
        payload.put("snippets", snippets);
        return ToolResult.ok(payload, snippets.isEmpty()
                ? "No matching workspace knowledge."
                : "%d knowledge snippet(s) found.".formatted(snippets.size()));
    }
}
