package com.microflow.agent.runtime.infrastructure.tool;

import com.microflow.agent.runtime.domain.model.AgentArtifact;
import com.microflow.agent.runtime.domain.model.ToolDescriptor;
import com.microflow.agent.runtime.domain.model.ToolPolicy;
import com.microflow.agent.runtime.domain.tool.AgentTool;
import com.microflow.agent.runtime.domain.tool.ToolContext;
import com.microflow.agent.runtime.domain.tool.ToolInputs;
import com.microflow.agent.runtime.domain.tool.ToolResult;
import com.microflow.agent.runtime.infrastructure.persistence.JdbcAgentRuntimeRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Component;

/** Stores a draft or summary as a run artifact. Internal write, no approval needed. */
@Component
public class ArtifactCreateTool implements AgentTool {

    private final JdbcAgentRuntimeRepository runtimeRepository;
    private final Clock clock;

    public ArtifactCreateTool(JdbcAgentRuntimeRepository runtimeRepository, Clock clock) {
        this.runtimeRepository = runtimeRepository;
        this.clock = clock;
    }

    @Override
    public ToolDescriptor descriptor() {
        return new ToolDescriptor(
                "artifact.create",
                "Save draft artifact",
                "Saves a draft, summary or checklist produced by the agent as a run artifact.",
                Map.of(
                        "type", "object",
                        "properties", Map.of(
                                "title", Map.of("type", "string"),
                                "content", Map.of("type", "string"),
                                "format", Map.of("type", "string", "enum", List.of("MARKDOWN", "TEXT"))
                        ),
                        "required", List.of("title", "content")
                ),
                ToolPolicy.Permission.AUTO,
                ToolPolicy.Risk.INTERNAL_WRITE,
                false,
                null
        );
    }

    @Override
    public ToolResult invoke(ToolContext context, Map<String, Object> input) {
        var title = ToolInputs.requiredString(input, "title");
        var content = ToolInputs.requiredString(input, "content");
        var format = ToolInputs.optionalString(input, "format");
        var artifactId = "art_" + UUID.randomUUID();
        runtimeRepository.insertArtifact(new AgentArtifact(
                artifactId,
                context.sessionId(),
                context.workspaceId(),
                format == null || format.isBlank() ? "MARKDOWN" : format.toUpperCase(java.util.Locale.ROOT),
                title,
                content.length() > 180 ? content.substring(0, 180) : content,
                content,
                null,
                Instant.now(clock).toString()
        ));
        return ToolResult.ok(Map.of("artifactId", artifactId, "title", title), "Artifact saved: " + title);
    }
}
