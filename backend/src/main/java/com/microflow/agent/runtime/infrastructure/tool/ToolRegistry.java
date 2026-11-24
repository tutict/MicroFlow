package com.microflow.agent.runtime.infrastructure.tool;

import com.microflow.agent.runtime.domain.model.ConnectorKind;
import com.microflow.agent.runtime.domain.model.ToolDescriptor;
import com.microflow.agent.runtime.domain.tool.AgentTool;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Component;

/**
 * Single source of truth for what an agent may call.
 *
 * <p>Wiring is explicit rather than a scanned collection: adding a tool without
 * deciding its permission and risk should be a compile-time decision, not a
 * side effect of putting {@code @Component} on a class.
 */
@Component
public class ToolRegistry {

    private final Map<String, AgentTool> tools = new LinkedHashMap<>();

    public ToolRegistry(
            KnowledgeSearchTool knowledgeSearchTool,
            TaskReadTool taskReadTool,
            TaskUpdateStatusTool taskUpdateStatusTool,
            ArtifactCreateTool artifactCreateTool,
            MailSearchTool mailSearchTool,
            MailSendTool mailSendTool,
            CalendarCreateEventTool calendarCreateEventTool,
            WebdavListTool webdavListTool,
            WebdavWriteTool webdavWriteTool
    ) {
        for (var tool : List.of(
                knowledgeSearchTool,
                taskReadTool,
                taskUpdateStatusTool,
                artifactCreateTool,
                mailSearchTool,
                mailSendTool,
                calendarCreateEventTool,
                webdavListTool,
                webdavWriteTool)) {
            tools.put(tool.descriptor().key(), tool);
        }
    }

    public List<ToolDescriptor> descriptors() {
        return tools.values().stream().map(AgentTool::descriptor).toList();
    }

    /**
     * The subset of the catalog worth offering on a specific run.
     *
     * <p>A connector-backed tool is hidden unless the initiator actually has a
     * usable connector for it. Otherwise the model sees an attractive tool it
     * can never complete, calls it, and the run fails on a capability the user
     * never claimed to have.
     */
    public List<ToolDescriptor> descriptorsFor(Set<ConnectorKind> availableConnectors) {
        return descriptors().stream()
                .filter(descriptor -> {
                    var required = descriptor.connectorKind();
                    if (required == null) {
                        return true;
                    }
                    return availableConnectors.stream()
                            .anyMatch(kind -> kind.name().equals(required));
                })
                .toList();
    }

    public AgentTool require(String toolKey) {
        var tool = tools.get(toolKey);
        if (tool == null) {
            throw new IllegalArgumentException("Unknown tool: " + toolKey);
        }
        return tool;
    }

    public boolean contains(String toolKey) {
        return tools.containsKey(toolKey);
    }
}
