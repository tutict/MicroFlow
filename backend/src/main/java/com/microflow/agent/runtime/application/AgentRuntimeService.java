package com.microflow.agent.runtime.application;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.microflow.agent.domain.model.AgentDescriptor;
import com.microflow.agent.infrastructure.persistence.JdbcAgentRepository;
import com.microflow.agent.runtime.domain.gateway.AgentTurnGateway;
import com.microflow.agent.runtime.domain.gateway.AgentTurnRequest;
import com.microflow.agent.runtime.domain.gateway.AgentTurnResult;
import com.microflow.agent.runtime.domain.gateway.ProviderCapability;
import com.microflow.agent.runtime.domain.gateway.TurnMessage;
import com.microflow.agent.runtime.domain.model.AgentApproval;
import com.microflow.agent.runtime.domain.model.AgentApprovalStatus;
import com.microflow.agent.runtime.domain.model.AgentArtifact;
import com.microflow.agent.runtime.domain.model.AgentRunEvent;
import com.microflow.agent.runtime.domain.model.AgentRunSession;
import com.microflow.agent.runtime.domain.model.AgentRunStatus;
import com.microflow.agent.runtime.domain.model.AgentRunStep;
import com.microflow.agent.runtime.domain.model.AgentToolInvocation;
import com.microflow.agent.runtime.domain.model.ToolCallRequest;
import com.microflow.agent.runtime.domain.model.ToolDescriptor;
import com.microflow.agent.runtime.domain.model.ToolPolicy;
import com.microflow.agent.runtime.domain.tool.AgentTool;
import com.microflow.agent.runtime.domain.tool.ToolContext;
import com.microflow.agent.runtime.domain.tool.ToolResult;
import com.microflow.agent.runtime.infrastructure.persistence.JdbcAgentRuntimeRepository;
import com.microflow.agent.runtime.infrastructure.tool.ToolRegistry;
import com.microflow.chat.infrastructure.persistence.JdbcMessageRepository;
import com.microflow.common.error.AccessDeniedException;
import com.microflow.common.error.ConcurrentModificationException;
import com.microflow.common.error.ResourceNotFoundException;
import com.microflow.realtime.broadcaster.RealtimeBroadcaster;
import com.microflow.realtime.protocol.RealtimeEvent;
import com.microflow.task.domain.model.TaskItem;
import com.microflow.task.infrastructure.persistence.JdbcTaskRepository;
import com.microflow.workspace.application.service.WorkspaceAccessGuard;
import com.microflow.workspace.domain.model.WorkspaceRole;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import jakarta.inject.Named;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/**
 * Durable runtime for one agent run.
 *
 * <p>Responsibilities, in order of importance:
 *
 * <ol>
 *   <li>never perform an external write without an approval row that a human
 *       approved;</li>
 *   <li>never infer a tool call from prose -- only structured provider output
 *       becomes an action;</li>
 *   <li>never silently replay an action whose outcome is unknown;</li>
 *   <li>leave an append-only event trail for every state change and tool call.</li>
 * </ol>
 */
@Service
public class AgentRuntimeService {

    private static final Logger log = LoggerFactory.getLogger(AgentRuntimeService.class);

    private static final String KIND_TASK = "TASK";

    private final JdbcAgentRuntimeRepository runtimeRepository;
    private final JdbcTaskRepository taskRepository;
    private final JdbcAgentRepository agentRepository;
    private final JdbcMessageRepository messageRepository;
    private final JdbcWorkspaceRepository workspaceRepository;
    private final WorkspaceAccessGuard accessGuard;
    private final AgentContextBuilder contextBuilder;
    private final AgentTurnGateway turnGateway;
    private final ProviderCapabilityService capabilityService;
    private final ToolRegistry toolRegistry;
    private final ConnectorResolver connectorResolver;
    private final RealtimeBroadcaster realtimeBroadcaster;
    private final ObjectMapper objectMapper;
    private final Clock clock;
    private final ExecutorService executor;
    private final int maxSteps;

    public AgentRuntimeService(
            JdbcAgentRuntimeRepository runtimeRepository,
            JdbcTaskRepository taskRepository,
            JdbcAgentRepository agentRepository,
            JdbcMessageRepository messageRepository,
            JdbcWorkspaceRepository workspaceRepository,
            WorkspaceAccessGuard accessGuard,
            AgentContextBuilder contextBuilder,
            AgentTurnGateway turnGateway,
            ProviderCapabilityService capabilityService,
            ToolRegistry toolRegistry,
            ConnectorResolver connectorResolver,
            RealtimeBroadcaster realtimeBroadcaster,
            ObjectMapper objectMapper,
            Clock clock,
            @Named("microflowVirtualThreadExecutor") ExecutorService executor,
            @Value("${microflow.agent.runtime.max-steps:8}") int maxSteps
    ) {
        this.runtimeRepository = runtimeRepository;
        this.taskRepository = taskRepository;
        this.agentRepository = agentRepository;
        this.messageRepository = messageRepository;
        this.workspaceRepository = workspaceRepository;
        this.accessGuard = accessGuard;
        this.contextBuilder = contextBuilder;
        this.turnGateway = turnGateway;
        this.capabilityService = capabilityService;
        this.toolRegistry = toolRegistry;
        this.connectorResolver = connectorResolver;
        this.realtimeBroadcaster = realtimeBroadcaster;
        this.objectMapper = objectMapper;
        this.clock = clock;
        this.executor = executor;
        this.maxSteps = Math.max(1, maxSteps);
    }

    // ------------------------------------------------------------------ commands

    public AgentRunSession startTaskRun(
            String userId,
            String workspaceId,
            String taskId,
            String agentKey,
            String goal
    ) {
        accessGuard.requireMember(workspaceId, userId);
        accessGuard.requireCapability(workspaceId, userId, WorkspaceRole.Capability.CREATE_TASK);
        var task = taskRepository.findTask(workspaceId, taskId)
                .orElseThrow(() -> new ResourceNotFoundException("Task not found: " + taskId));
        var resolvedAgentKey = resolveAgentKey(workspaceId, agentKey);
        var resolvedGoal = goal == null || goal.isBlank()
                ? "Help move the task forward: " + task.title()
                : goal.trim();
        var now = Instant.now(clock).toString();
        var session = new AgentRunSession(
                "run_" + UUID.randomUUID(),
                workspaceId,
                taskId,
                task.originChannelId(),
                null,
                userId,
                resolvedAgentKey,
                KIND_TASK,
                AgentRunStatus.QUEUED,
                resolvedGoal,
                null,
                null,
                "NONE",
                null,
                0,
                0,
                0,
                now,
                null,
                null,
                now
        );
        runtimeRepository.insertSession(session);
        publish(session, "RUN_QUEUED", Map.of(
                "taskId", taskId,
                "agentKey", resolvedAgentKey,
                "goal", resolvedGoal
        ));
        executor.submit(() -> executeRun(session.id()));
        return session;
    }

    public AgentRunSession cancel(String userId, String runId) {
        var session = requireRun(runId);
        accessGuard.requireMember(session.workspaceId(), userId);
        var role = accessGuard.roleOf(session.workspaceId(), userId);
        if (!session.initiatorUserId().equals(userId)
                && (role == null || !role.can(WorkspaceRole.Capability.ADVANCE_ANY_TASK))) {
            throw new AccessDeniedException("Only the initiator or a maintainer may cancel this run");
        }
        if (session.status().isTerminal()) {
            return session;
        }
        var moved = runtimeRepository.updateStatus(
                runId, session.status(), AgentRunStatus.CANCELLED, null, null, now());
        if (!moved) {
            throw new ConcurrentModificationException("Run " + runId + " changed status while cancelling");
        }
        runtimeRepository.cancelPendingApprovals(runId);
        var cancelled = requireRun(runId);
        publish(cancelled, "RUN_CANCELLED", Map.of("cancelledBy", userId));
        return cancelled;
    }

    public AgentRunSession retry(String userId, String runId) {
        var session = requireRun(runId);
        accessGuard.requireMember(session.workspaceId(), userId);
        accessGuard.requireCapability(session.workspaceId(), userId, WorkspaceRole.Capability.CREATE_TASK);
        if (!session.status().canRetry()) {
            throw new IllegalArgumentException("Only a failed run can be retried");
        }
        if (runtimeRepository.hasUnknownInvocation(runId)) {
            throw new ConcurrentModificationException(
                    "A previous external action has an unknown outcome; verify it before retrying");
        }
        if (!runtimeRepository.resetForRetry(runId)) {
            throw new ConcurrentModificationException(
                    "Run changed or has an unknown external outcome; reload before retrying");
        }
        var retried = requireRun(runId);
        publish(retried, "RUN_RETRY_REQUESTED", Map.of("requestedBy", userId,
                "attempt", retried.attemptCount()));
        executor.submit(() -> executeRun(runId));
        return retried;
    }

    public AgentApproval decideApproval(
            String userId,
            String runId,
            String approvalId,
            String decision,
            String note
    ) {
        var session = requireRun(runId);
        accessGuard.requireMember(session.workspaceId(), userId);
        accessGuard.requireCapability(session.workspaceId(), userId, WorkspaceRole.Capability.CREATE_TASK);
        var approval = runtimeRepository.findApproval(approvalId)
                .orElseThrow(() -> new ResourceNotFoundException("Approval not found: " + approvalId));
        if (!approval.sessionId().equals(runId)) {
            throw new ResourceNotFoundException("Approval " + approvalId + " does not belong to run " + runId);
        }
        var target = parseDecision(decision);
        toolRegistry.require(approval.toolKey()).authorize(new ToolContext(
                runId, session.workspaceId(), session.taskId(), session.channelId(),
                session.initiatorUserId(), session.agentKey(), approvalId), userId,
                readInputJson(approval.inputJson()));
        if (!runtimeRepository.decideApproval(approvalId, target, userId, normalizeNote(note))) {
            throw new ConcurrentModificationException("Approval " + approvalId + " is no longer pending");
        }
        var decided = runtimeRepository.findApproval(approvalId).orElseThrow();
        publish(session, target == AgentApprovalStatus.APPROVED ? "APPROVAL_APPROVED" : "APPROVAL_REJECTED",
                Map.of(
                        "approvalId", approvalId,
                        "toolKey", approval.toolKey(),
                        "decidedBy", userId,
                        "note", normalizeNote(note) == null ? "" : normalizeNote(note)
                ));

        if (session.status() != AgentRunStatus.WAITING_APPROVAL) {
            // The run was cancelled (or finished) while the approval was pending.
            return decided;
        }
        if (!runtimeRepository.updateStatus(
                runId, AgentRunStatus.WAITING_APPROVAL, AgentRunStatus.RUNNING, null, null, null)) {
            throw new ConcurrentModificationException("Run " + runId + " is no longer waiting for approval");
        }
        publish(requireRun(runId), "RUN_RESUMED", Map.of("approvalId", approvalId));
        executor.submit(() -> resumeAfterApproval(runId, approvalId));
        return decided;
    }

    // ------------------------------------------------------------------- queries

    public AgentRunSession requireRun(String runId) {
        return runtimeRepository.findSession(runId)
                .orElseThrow(() -> new ResourceNotFoundException("Agent run not found: " + runId));
    }

    public AgentRunSession findRun(String userId, String runId) {
        var session = requireRun(runId);
        accessGuard.requireMember(session.workspaceId(), userId);
        return session;
    }

    public List<AgentRunSession> listRuns(
            String userId,
            String workspaceId,
            String taskId,
            String status,
            int limit
    ) {
        accessGuard.requireMember(workspaceId, userId);
        return runtimeRepository.listSessions(workspaceId, taskId, status, limit);
    }

    public List<AgentRunSession> listRuns(String userId, String workspaceId, String taskId,
            String status, int limit, boolean activeOnly, String afterId) {
        accessGuard.requireMember(workspaceId, userId);
        if (activeOnly) {
            if (status != null && !status.isBlank()) {
                throw new IllegalArgumentException("Use either status or activeOnly");
            }
            return runtimeRepository.listActiveSessions(workspaceId, taskId, afterId, Math.min(200, Math.max(1, limit)));
        }
        if (afterId != null && !afterId.isBlank()) {
            throw new IllegalArgumentException("afterId requires activeOnly");
        }
        return runtimeRepository.listSessions(workspaceId, taskId, status, limit);
    }

    public List<AgentRunEvent> listEvents(String userId, String runId, long afterSeq, int limit) {
        findRun(userId, runId);
        return runtimeRepository.listEvents(runId, afterSeq, limit);
    }

    public List<AgentRunStep> listSteps(String userId, String runId) {
        findRun(userId, runId);
        return runtimeRepository.listSteps(runId);
    }

    public List<AgentArtifact> listArtifacts(String userId, String runId) {
        findRun(userId, runId);
        return runtimeRepository.listArtifacts(runId);
    }

    public List<com.microflow.agent.runtime.domain.model.AgentContextSource> listContextSources(
            String userId,
            String runId
    ) {
        findRun(userId, runId);
        return runtimeRepository.listContextSources(runId);
    }

    public List<AgentApproval> listApprovals(String userId, String runId, String status) {
        findRun(userId, runId);
        return runtimeRepository.listApprovals(runId, status);
    }

    public Optional<AgentApproval> pendingApproval(String runId) {
        return runtimeRepository.findPendingApproval(runId);
    }

    public List<AgentToolInvocation> listInvocations(String userId, String runId) {
        findRun(userId, runId);
        return runtimeRepository.listInvocations(runId);
    }

    public List<ToolDescriptor> toolCatalog() {
        return toolRegistry.descriptors();
    }

    public Map<String, String> pendingApprovalIds(String userId, String workspaceId) {
        accessGuard.requireMember(workspaceId, userId);
        return runtimeRepository.pendingApprovalIds(workspaceId);
    }

    /**
     * Startup recovery.
     *
     * <p>Queued runs are safe to start again. Runs caught mid-flight are not:
     * the process may have died after an external call landed, so they are
     * marked interrupted and require a human retry. Approvals simply stay
     * pending and remain valid.
     */
    public RecoveryReport recoverAfterRestart() {
        var interrupted = 0;
        var requeued = 0;
        for (var status : List.of("CONTEXT_BUILDING", "RUNNING")) {
            String afterId = null;
            while (true) {
                var page = runtimeRepository.listSessionsByStatus(status, afterId, 200);
                if (page.isEmpty()) break;
                for (var session : page) {
                    if (runtimeRepository.markInterrupted(session.id(),
                            "Run interrupted by a process restart; retry after checking external state")) {
                        publish(requireRun(session.id()), "RUN_INTERRUPTED", Map.of(
                                "reason", "PROCESS_RESTART", "previousStatus", status));
                        interrupted++;
                    }
                }
                afterId = page.getLast().id();
            }
        }
        String afterId = null;
        while (true) {
            var page = runtimeRepository.listSessionsByStatus("QUEUED", afterId, 200);
            if (page.isEmpty()) break;
            for (var session : page) {
                executor.submit(() -> executeRun(session.id()));
                requeued++;
            }
            afterId = page.getLast().id();
        }
        return new RecoveryReport(interrupted, requeued);
    }

    public record RecoveryReport(int interruptedRuns, int requeuedRuns) {
    }

    // ------------------------------------------------------------------ execution

    void executeRun(String runId) {
        var session = runtimeRepository.findSession(runId).orElse(null);
        if (session == null || session.status() != AgentRunStatus.QUEUED) {
            return;
        }
        try {
            if (!runtimeRepository.updateStatus(
                    runId, AgentRunStatus.QUEUED, AgentRunStatus.CONTEXT_BUILDING, null, null, null)) {
                return;
            }
            publish(requireRun(runId), "RUN_CONTEXT_BUILDING", Map.of());
            var building = requireRun(runId);
            var context = contextBuilder.build(building);
            runtimeRepository.replaceContextSources(runId, building.workspaceId(), context.sources());
            runtimeRepository.appendMessage(runId, new TurnMessage("system", context.block(), List.of(), null));
            runtimeRepository.appendMessage(runId, TurnMessage.user(building.goal()));
            runtimeRepository.setContextSummary(runId, context.summary(), 0);
            publish(building, "RUN_CONTEXT_READY", Map.of(
                    "summary", context.summary(),
                    "sources", context.sources().stream()
                            .map(source -> Map.of(
                                    "type", source.sourceType(),
                                    "label", source.label(),
                                    "refId", source.refId() == null ? "" : source.refId()))
                            .toList()
            ));

            if (!runtimeRepository.updateStatus(
                    runId, AgentRunStatus.CONTEXT_BUILDING, AgentRunStatus.RUNNING,
                    null, now(), null)) {
                return;
            }
            publish(requireRun(runId), "RUN_STARTED", Map.of());
            loop(runId);
        } catch (Exception exception) {
            log.error("Agent run {} failed during setup", runId, exception);
            failRun(runId, messageOf(exception));
        }
    }

    private void loop(String runId) {
        var session = requireRun(runId);
        var capability = capabilityService.resolve(session.workspaceId(), session.agentKey());
        if (!capability.supportsToolCalls()) {
            publish(session, "TOOLS_DISABLED", Map.of(
                    "detail", capability.detail() == null ? "" : capability.detail()));
        }
        // Connector-backed tools are only offered when this initiator can actually
        // use one; an unreachable tool invites the model to fail on it.
        var offeredTools = capability.supportsToolCalls()
                ? toolRegistry.descriptorsFor(connectorResolver.availableKinds(
                        session.workspaceId(), session.initiatorUserId(), session.agentKey())).stream()
                        .filter(descriptor -> descriptor.connectorKind() == null || connectorResolver.isAvailable(
                                session.workspaceId(), session.initiatorUserId(), session.agentKey(),
                                com.microflow.agent.runtime.domain.model.ConnectorKind.valueOf(descriptor.connectorKind()),
                                descriptor.risk() != ToolPolicy.Risk.READ_ONLY))
                        .toList()
                : List.<ToolDescriptor>of();
        var allowedToolKeys = offeredTools.stream().map(ToolDescriptor::key)
                .collect(java.util.stream.Collectors.toUnmodifiableSet());
        if (!completePendingToolCalls(runId, allowedToolKeys)) {
            return;
        }
        var messages = currentAttemptMessages(runId);
        var contextBlock = messages.stream()
                .filter(message -> "system".equals(message.role()))
                .map(TurnMessage::content)
                .findFirst()
                .orElse("");
        var conversation = new ArrayList<>(messages.stream()
                .filter(message -> !"system".equals(message.role()))
                .toList());

        var completedTurns = (int) conversation.stream()
                .filter(message -> "assistant".equals(message.role())).count();
        for (var step = completedTurns; step < maxSteps; step++) {
            var current = requireRun(runId);
            if (current.status() != AgentRunStatus.RUNNING) {
                return;
            }
            var request = new AgentTurnRequest(
                    runId,
                    current.workspaceId(),
                    current.channelId(),
                    current.agentKey(),
                    current.goal(),
                    contextBlock,
                    List.copyOf(conversation),
                    offeredTools,
                    capability.supportsToolCalls()
            );
            var result = runModelTurn(request);
            if (requireRun(runId).status() != AgentRunStatus.RUNNING) {
                return;
            }
            if (result.kind() == AgentTurnResult.Kind.FAILED) {
                failRun(runId, result.error());
                return;
            }
            if (result.kind() == AgentTurnResult.Kind.TEXT) {
                runtimeRepository.appendMessage(runId,
                        new TurnMessage("assistant", result.text(), List.of(), null));
                succeedRun(runId, result.text());
                return;
            }

            if (!capability.supportsToolCalls()
                    || result.toolCalls().stream().anyMatch(call -> !allowedToolKeys.contains(call.toolKey()))) {
                failRun(runId, "Provider requested a tool that was not offered to this run");
                return;
            }

            // A new turn cannot reuse an earlier turn's idempotency key. Check
            // the whole batch before admitting even its first action.
            var seenCallIds = conversation.stream().flatMap(message -> message.toolCalls().stream())
                    .map(ToolCallRequest::callId)
                    .collect(java.util.stream.Collectors.toCollection(java.util.HashSet::new));
            for (var call : result.toolCalls()) {
                if (call.callId() == null || call.callId().isBlank() || !seenCallIds.add(call.callId())) {
                    failRun(runId, "Provider returned a missing or reused tool call ID");
                    return;
                }
            }

            var assistantMessage = new TurnMessage(
                    "assistant", result.text(), result.toolCalls(), null);
            runtimeRepository.appendMessage(runId, assistantMessage);
            conversation.add(assistantMessage);

            for (var call : result.toolCalls()) {
                var outcome = handleToolCall(runId, call);
                if (outcome.paused()) {
                    return;
                }
                var toolMessage = TurnMessage.tool(call.callId(), outcome.content());
                runtimeRepository.appendMessage(runId, toolMessage);
                conversation.add(toolMessage);
            }
        }
        failRun(runId, "Run exceeded the maximum of %d agent steps".formatted(maxSteps));
    }

    /** Previous attempts remain in the audit, but are not sent as the current conversation. */
    private List<TurnMessage> currentAttemptMessages(String runId) {
        var messages = runtimeRepository.listMessages(runId);
        for (var index = messages.size() - 1; index >= 0; index--) {
            if ("system".equals(messages.get(index).role())) {
                return messages.subList(index, messages.size());
            }
        }
        return messages;
    }

    /** A pause may leave several calls in one assistant message without a tool response. */
    private boolean completePendingToolCalls(String runId, java.util.Set<String> allowedToolKeys) {
        var messages = currentAttemptMessages(runId);
        var answered = new java.util.HashSet<String>();
        for (var message : messages) {
            if ("tool".equals(message.role())) {
                answered.add(message.toolCallId());
            }
        }
        for (var message : messages) {
            if (!"assistant".equals(message.role())) continue;
            for (var call : message.toolCalls()) {
                if (answered.contains(call.callId())) continue;
                if (requireRun(runId).status() != AgentRunStatus.RUNNING) return false;
                if (!allowedToolKeys.contains(call.toolKey())) {
                    failRun(runId, "A pending tool is no longer available to this run");
                    return false;
                }
                var outcome = handleToolCall(runId, call);
                if (outcome.paused()) return false;
                runtimeRepository.appendMessage(runId, TurnMessage.tool(call.callId(), outcome.content()));
                answered.add(call.callId());
            }
        }
        return true;
    }

    private AgentTurnResult runModelTurn(AgentTurnRequest request) {
        var step = runtimeRepository.createStep(request.sessionId(), "MODEL_TURN", "RUNNING",
                request.agentKey(), "Agent: @" + request.agentKey(), null);
        publish(requireRun(request.sessionId()), "MODEL_TURN_STARTED", Map.of("stepId", step.id()));
        try {
            var result = turnGateway.turn(request);
            var status = result.kind() == AgentTurnResult.Kind.FAILED ? "FAILED" : "COMPLETED";
            runtimeRepository.finishStep(step.id(), status,
                    result.kind() == AgentTurnResult.Kind.FAILED ? result.error() : result.text());
            publish(requireRun(request.sessionId()), "MODEL_TURN_" + status, Map.of("stepId", step.id()));
            return result;
        } catch (Exception exception) {
            runtimeRepository.finishStep(step.id(), "FAILED", messageOf(exception));
            publish(requireRun(request.sessionId()), "MODEL_TURN_FAILED", Map.of("stepId", step.id()));
            throw exception;
        }
    }

    private void resumeAfterApproval(String runId, String approvalId) {
        var session = requireRun(runId);
        if (session.status() != AgentRunStatus.RUNNING) {
            return;
        }
        var approval = runtimeRepository.findApproval(approvalId).orElse(null);
        if (approval == null) {
            failRun(runId, "Approval disappeared before the run resumed");
            return;
        }
        var invocation = runtimeRepository.listInvocations(runId).stream()
                .filter(item -> approvalId.equals(item.approvalId()))
                .findFirst()
                .orElse(null);
        if (invocation == null) {
            failRun(runId, "Approved action could not be located");
            return;
        }
        try {
            String content;
            if (approval.status() == AgentApprovalStatus.APPROVED) {
                var executed = executeInvocation(session, invocation);
                if (executed.paused()) {
                    if (requireRun(runId).status() == AgentRunStatus.FAILED) {
                        runtimeRepository.finishStep(approval.stepId(), "FAILED", "Manual verification required");
                    }
                    return;
                }
                runtimeRepository.finishStep(approval.stepId(), "COMPLETED", executed.content());
                content = executed.content();
            } else {
                runtimeRepository.updateInvocation(
                        invocation.id(), AgentToolInvocation.Status.REJECTED, null,
                        "Rejected by " + approval.decidedByUserId(), false);
                runtimeRepository.finishStep(approval.stepId(), "REJECTED", approval.decisionNote());
                content = "The user rejected this action"
                        + (approval.decisionNote() == null ? "." : ": " + approval.decisionNote());
                publish(session, "TOOL_REJECTED", Map.of(
                        "toolKey", invocation.toolKey(),
                        "invocationId", invocation.id()));
            }
            runtimeRepository.appendMessage(runId, TurnMessage.tool(invocation.idempotencyKey(), content));
            loop(runId);
        } catch (Exception exception) {
            log.error("Resuming run {} after approval failed", runId, exception);
            failRun(runId, messageOf(exception));
        }
    }

    private ToolCallOutcome handleToolCall(String runId, ToolCallRequest call) {
        var session = requireRun(runId);
        if (session.status() != AgentRunStatus.RUNNING) {
            return new ToolCallOutcome(true, "");
        }
        var existing = runtimeRepository.findInvocationByKey(runId, call.callId());
        if (existing.isPresent()) {
            var invocation = existing.get();
            if (!invocation.toolKey().equals(call.toolKey()) || !readInput(invocation).equals(call.inputOrEmpty())) {
                failRun(runId, "Provider reused a tool call ID for a different action");
                return new ToolCallOutcome(true, "");
            }
            return switch (invocation.status()) {
                case SUCCEEDED -> new ToolCallOutcome(false,
                        invocation.outputJson() == null ? "Completed." : invocation.outputJson());
                case REJECTED -> new ToolCallOutcome(false, "The user rejected this action.");
                case CANCELLED -> new ToolCallOutcome(true, "The run was cancelled.");
                case FAILED -> new ToolCallOutcome(false, "Tool failed: " + invocation.errorMessage());
                case UNKNOWN -> {
                    failRun(runId, "A previous external action has an unknown outcome; manual verification required");
                    yield new ToolCallOutcome(true, "");
                }
                case AWAITING_APPROVAL -> {
                    // A pending approval already exists for this call; just stay paused.
                    yield new ToolCallOutcome(true, "");
                }
                default -> new ToolCallOutcome(false, "This action is still in progress.");
            };
        }

        ToolDescriptor descriptor;
        try {
            descriptor = toolRegistry.require(call.toolKey()).descriptor();
        } catch (IllegalArgumentException exception) {
            publish(session, "TOOL_UNKNOWN", Map.of("toolKey", call.toolKey()));
            return new ToolCallOutcome(false, "Unknown tool: " + call.toolKey());
        }

        if (descriptor.requiresApproval()) {
            pauseForApproval(runId, call, descriptor);
            return new ToolCallOutcome(true, "");
        }

        var invocation = createInvocation(session, call, descriptor, AgentToolInvocation.Status.PENDING, null);
        return executeInvocation(session, invocation);
    }

    private ToolCallOutcome executeInvocation(AgentRunSession session, AgentToolInvocation invocation) {
        if (requireRun(session.id()).status() != AgentRunStatus.RUNNING) {
            return new ToolCallOutcome(true, "");
        }
        AgentTool tool = toolRegistry.require(invocation.toolKey());
        var context = new ToolContext(session.id(), session.workspaceId(), session.taskId(),
                session.channelId(), session.initiatorUserId(), session.agentKey(), invocation.approvalId());
        Map<String, Object> input;
        try {
            input = readInput(invocation);
            var actorUserId = invocation.approvalId() == null ? session.initiatorUserId()
                    : runtimeRepository.findApproval(invocation.approvalId())
                            .map(AgentApproval::decidedByUserId).orElse(null);
            tool.authorize(context, actorUserId, input);
        } catch (Exception exception) {
            if (requireRun(session.id()).status() == AgentRunStatus.RUNNING) {
                var error = messageOf(exception);
                runtimeRepository.updateInvocation(invocation.id(), AgentToolInvocation.Status.FAILED,
                        null, error, false);
                publish(session, "TOOL_FAILED", Map.of("toolKey", invocation.toolKey(), "error", error));
                failRun(session.id(), "Tool authorization or input validation failed: " + error);
            }
            return new ToolCallOutcome(true, "");
        }
        if (!runtimeRepository.claimInvocation(invocation.id())) {
            return new ToolCallOutcome(true, "");
        }
        var step = runtimeRepository.createStep(
                session.id(),
                "TOOL",
                "RUNNING",
                session.agentKey(),
                "Tool: " + invocation.toolKey(),
                invocation.inputJson()
        );
        publish(session, "TOOL_STARTED", Map.of(
                "toolKey", invocation.toolKey(),
                "invocationId", invocation.id(),
                "risk", invocation.riskLevel()
        ));
        try {
            var descriptor = tool.descriptor();
            if (requireRun(session.id()).status() != AgentRunStatus.RUNNING) {
                runtimeRepository.updateInvocation(invocation.id(), AgentToolInvocation.Status.CANCELLED,
                        null, "Run cancelled before the tool started", false);
                runtimeRepository.finishStep(step.id(), "CANCELLED", "Run cancelled before the tool started");
                return new ToolCallOutcome(true, "");
            }
            var result = tool.invoke(context, input);
            if (result.uncertain()) {
                runtimeRepository.updateInvocation(
                        invocation.id(), AgentToolInvocation.Status.UNKNOWN, null, result.error(), true);
                runtimeRepository.finishStep(step.id(), "FAILED", result.error());
                publish(session, "TOOL_UNKNOWN", Map.of(
                        "toolKey", invocation.toolKey(),
                        "invocationId", invocation.id(),
                        "error", result.error() == null ? "" : result.error()
                ));
                failRun(session.id(),
                        "External action outcome is unknown; verify manually before retrying");
                return new ToolCallOutcome(true, "");
            }
            if (!result.success()) {
                runtimeRepository.updateInvocation(
                        invocation.id(), AgentToolInvocation.Status.FAILED, null, result.error(), true);
                runtimeRepository.finishStep(step.id(), "FAILED", result.error());
                publish(session, "TOOL_FAILED", Map.of(
                        "toolKey", invocation.toolKey(),
                        "invocationId", invocation.id(),
                        "error", result.error() == null ? "" : result.error()
                ));
                return new ToolCallOutcome(false, "Tool failed: " + result.error());
            }
            var outputJson = writeJson(result.output());
            runtimeRepository.updateInvocation(
                    invocation.id(), AgentToolInvocation.Status.SUCCEEDED, outputJson, null, true);
            runtimeRepository.finishStep(step.id(), "COMPLETED", result.summary());
            publish(session, "TOOL_COMPLETED", Map.of(
                    "toolKey", invocation.toolKey(),
                    "invocationId", invocation.id(),
                    "summary", result.summary() == null ? "" : result.summary()
            ));
            return new ToolCallOutcome(false,
                    result.summary() == null ? outputJson : result.summary() + "\n" + outputJson);
        } catch (Exception exception) {
            var message = messageOf(exception);
            var descriptor = lookupDescriptor(invocation.toolKey());
            var status = descriptor.risk().isExternal()
                    ? AgentToolInvocation.Status.UNKNOWN
                    : AgentToolInvocation.Status.FAILED;
            runtimeRepository.updateInvocation(invocation.id(), status, null, message, true);
            runtimeRepository.finishStep(step.id(), "FAILED", message);
            publish(session, status == AgentToolInvocation.Status.UNKNOWN ? "TOOL_UNKNOWN" : "TOOL_FAILED",
                    Map.of("toolKey", invocation.toolKey(), "invocationId", invocation.id(), "error", message));
            if (status == AgentToolInvocation.Status.UNKNOWN) {
                failRun(session.id(),
                        "External action outcome is unknown; verify manually before retrying");
                return new ToolCallOutcome(true, "");
            }
            return new ToolCallOutcome(false, "Tool failed: " + message);
        }
    }

    private void pauseForApproval(String runId, ToolCallRequest call, ToolDescriptor descriptor) {
        var session = requireRun(runId);
        var step = runtimeRepository.createStep(
                runId, "APPROVAL", "RUNNING", session.agentKey(),
                "Approval required: " + descriptor.title(), null);
        var inputJson = writeJson(call.inputOrEmpty());
        var approvalId = "apr_" + UUID.randomUUID();
        var invocation = createInvocation(
                session, call, descriptor, AgentToolInvocation.Status.AWAITING_APPROVAL, approvalId);
        var approval = new AgentApproval(
                approvalId,
                runId,
                session.workspaceId(),
                step.id(),
                descriptor.key(),
                descriptor.title(),
                targetResource(session, call),
                descriptor.risk().name(),
                impactSummary(session, descriptor, call),
                inputJson,
                AgentApprovalStatus.PENDING,
                null,
                null,
                now(),
                null
        );
        runtimeRepository.insertApproval(approval);
        if (!runtimeRepository.updateStatus(
                runId, AgentRunStatus.RUNNING, AgentRunStatus.WAITING_APPROVAL, null, null, null)) {
            if (requireRun(runId).status() == AgentRunStatus.CANCELLED) {
                runtimeRepository.cancelPendingApprovals(runId);
            }
            throw new ConcurrentModificationException("Run " + runId + " is no longer running");
        }
        publish(requireRun(runId), "APPROVAL_REQUESTED", Map.of(
                "approvalId", approvalId,
                "toolKey", descriptor.key(),
                "action", descriptor.title(),
                "target", approval.targetResource(),
                "risk", descriptor.risk().name(),
                "impact", approval.impactSummary(),
                "input", call.inputOrEmpty(),
                "invocationId", invocation.id()
        ));
        publish(requireRun(runId), "RUN_WAITING_APPROVAL", Map.of("approvalId", approvalId));
    }

    private AgentToolInvocation createInvocation(
            AgentRunSession session,
            ToolCallRequest call,
            ToolDescriptor descriptor,
            AgentToolInvocation.Status status,
            String approvalId
    ) {
        var invocation = new AgentToolInvocation(
                "inv_" + UUID.randomUUID(),
                session.id(),
                session.workspaceId(),
                null,
                descriptor.key(),
                call.callId() == null || call.callId().isBlank()
                        ? "call_" + UUID.randomUUID()
                        : call.callId(),
                status,
                descriptor.risk().name(),
                writeJson(call.inputOrEmpty()),
                null,
                approvalId,
                null,
                0,
                now(),
                null
        );
        runtimeRepository.insertInvocation(invocation);
        return invocation;
    }

    private void succeedRun(String runId, String text) {
        var session = requireRun(runId);
        var output = text == null ? "" : text.trim();
        if (session.channelId() != null && !session.channelId().isBlank() && !output.isBlank()) {
            var message = messageRepository.saveAgentMessage(
                    session.workspaceId(), session.channelId(), session.agentKey(), output);
            realtimeBroadcaster.publishToChannel(
                    session.channelId(), new RealtimeEvent("MESSAGE_CREATED", message));
        }
        if (!output.isBlank()) {
            runtimeRepository.insertArtifact(new AgentArtifact(
                    "art_" + UUID.randomUUID(),
                    runId,
                    session.workspaceId(),
                    "RUN_SUMMARY",
                    "Run summary",
                    output.length() <= 180 ? output : output.substring(0, 180),
                    output,
                    null,
                    now()
            ));
            publish(session, "ARTIFACT_CREATED", Map.of("kind", "RUN_SUMMARY", "title", "Run summary"));
        }
        if (runtimeRepository.updateStatus(
                runId, AgentRunStatus.RUNNING, AgentRunStatus.SUCCEEDED, null, null, now())) {
            publish(requireRun(runId), "RUN_SUCCEEDED", Map.of("output", output));
        }
    }

    private void failRun(String runId, String error) {
        var session = runtimeRepository.findSession(runId).orElse(null);
        if (session == null || session.status().isTerminal()) {
            return;
        }
        if (runtimeRepository.updateStatus(
                runId, session.status(), AgentRunStatus.FAILED, error, null, now())) {
            publish(requireRun(runId), "RUN_FAILED", Map.of("error", error == null ? "" : error));
        }
    }

    // -------------------------------------------------------------------- events

    private void publish(AgentRunSession session, String type, Map<String, Object> payload) {
        var latest = requireRun(session.id());
        var snapshot = objectMapper.convertValue(latest, new TypeReference<Map<String, Object>>() { });
        snapshot.put("kind", latest.runKind());
        snapshot.remove("runKind");
        snapshot.put("pendingApprovalId", runtimeRepository.findPendingApproval(session.id())
                .map(AgentApproval::id).orElse(null));
        var fields = new LinkedHashMap<String, Object>();
        fields.put("runId", session.id());
        fields.put("workspaceId", session.workspaceId());
        fields.put("status", latest.status().name());
        fields.put("run", snapshot);
        if (latest.taskId() != null) fields.put("taskId", latest.taskId());
        fields.put("at", now());
        fields.putAll(payload);
        var seq = runtimeRepository.appendEvent(
                session.id(), session.workspaceId(), type, writeJson(fields));
        fields.put("seq", seq);
        fields.put("type", type);
        var event = new RealtimeEvent("AGENT_RUN_EVENT", fields);
        if (session.channelId() != null && !session.channelId().isBlank()) {
            realtimeBroadcaster.publishToChannel(session.channelId(), event);
            realtimeBroadcaster.publishToUser(session.initiatorUserId(), event);
        } else {
            // A task can have no originating channel. Its readers still need
            // progress while connected; channel subscriptions cannot deliver it.
            for (var member : workspaceRepository.findMembers(session.workspaceId(), session.initiatorUserId())) {
                realtimeBroadcaster.publishToUser(member.userId(), event);
            }
        }
        if (session.channelId() != null && !session.channelId().isBlank()
                && (type.startsWith("RUN_") || type.startsWith("APPROVAL_"))) {
            realtimeBroadcaster.publishToChannel(session.channelId(), new RealtimeEvent(
                    "AGENT_RUN_UPDATED",
                    Map.of("runId", session.id(), "status", session.status().name())));
        }
    }

    // ------------------------------------------------------------------- helpers

    private String resolveAgentKey(String workspaceId, String requested) {
        if (requested != null && !requested.isBlank()) {
            if (!agentRepository.existsAgent(workspaceId, requested)) {
                throw new IllegalArgumentException("Agent is not configured: " + requested);
            }
            return requested;
        }
        return agentRepository.listAgents(workspaceId).stream()
                .filter(AgentDescriptor::enabled)
                .map(AgentDescriptor::agentKey)
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException(
                        "No enabled agent is configured for this workspace"));
    }

    private AgentApprovalStatus parseDecision(String decision) {
        var normalized = decision == null ? "" : decision.trim().toUpperCase(java.util.Locale.ROOT);
        return switch (normalized) {
            case "APPROVE", "APPROVED" -> AgentApprovalStatus.APPROVED;
            case "REJECT", "REJECTED" -> AgentApprovalStatus.REJECTED;
            default -> throw new IllegalArgumentException("Decision must be APPROVE or REJECT");
        };
    }

    private ToolDescriptor lookupDescriptor(String toolKey) {
        return toolRegistry.require(toolKey).descriptor();
    }

    private String targetResource(AgentRunSession session, ToolCallRequest call) {
        var taskId = call.inputOrEmpty().get("taskId");
        if (taskId instanceof String text && !text.isBlank()) {
            return "task:" + text;
        }
        if (session.taskId() != null) {
            return "task:" + session.taskId();
        }
        return "workspace:" + session.workspaceId();
    }

    private String impactSummary(AgentRunSession session, ToolDescriptor descriptor, ToolCallRequest call) {
        if ("task.update_status".equals(descriptor.key()) && session.taskId() != null) {
            var task = taskRepository.findTask(session.workspaceId(), session.taskId());
            var status = call.inputOrEmpty().get("status");
            if (task.isPresent() && status instanceof String text) {
                TaskItem item = task.get();
                return "Move task \"%s\" from %s to %s."
                        .formatted(item.title(), item.status().storedValue(), text);
            }
        }
        return "Run %s with %s.".formatted(
                descriptor.title(), writeJson(call.inputOrEmpty()));
    }

    private Map<String, Object> readInput(AgentToolInvocation invocation) {
        return readInputJson(invocation.inputJson());
    }

    private Map<String, Object> readInputJson(String inputJson) {
        if (inputJson == null || inputJson.isBlank()) {
            throw new IllegalArgumentException("Stored tool input must be a JSON object");
        }
        try {
            Map<String, Object> input = objectMapper.readerFor(new TypeReference<LinkedHashMap<String, Object>>() { })
                    .with(com.fasterxml.jackson.databind.DeserializationFeature.FAIL_ON_TRAILING_TOKENS)
                    .readValue(inputJson);
            if (input == null) {
                throw new IllegalArgumentException("Stored tool input must be a JSON object");
            }
            return input;
        } catch (Exception exception) {
            throw new IllegalArgumentException("Stored tool input must be a JSON object", exception);
        }
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to serialize runtime payload", exception);
        }
    }

    private String now() {
        return Instant.now(clock).toString();
    }

    private String normalizeNote(String note) {
        if (note == null || note.isBlank()) {
            return null;
        }
        var trimmed = note.trim();
        return trimmed.length() <= 500 ? trimmed : trimmed.substring(0, 500);
    }

    private String messageOf(Exception exception) {
        return exception.getMessage() == null
                ? exception.getClass().getSimpleName()
                : exception.getMessage();
    }

    private record ToolCallOutcome(boolean paused, String content) {
    }
}
