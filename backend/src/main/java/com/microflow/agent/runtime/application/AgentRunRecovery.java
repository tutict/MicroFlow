package com.microflow.agent.runtime.application;

import io.quarkus.runtime.StartupEvent;
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Resumes what is safe to resume when the process starts.
 *
 * <p>Runs in a lower-priority observer than schema maintenance so the runtime
 * tables exist before anything is read. Interrupted runs are not replayed
 * automatically: a crash may have happened after an external side effect landed,
 * and guessing there is exactly the mistake the approval model exists to avoid.
 */
@ApplicationScoped
public class AgentRunRecovery {

    private static final Logger log = LoggerFactory.getLogger(AgentRunRecovery.class);

    private final AgentRuntimeService runtimeService;

    public AgentRunRecovery(AgentRuntimeService runtimeService) {
        this.runtimeService = runtimeService;
    }

    void onStart(@Observes @Priority(5000) StartupEvent event) {
        try {
            var report = runtimeService.recoverAfterRestart();
            if (report.interruptedRuns() > 0 || report.requeuedRuns() > 0) {
                log.info("Agent runtime recovered: {} interrupted, {} requeued",
                        report.interruptedRuns(), report.requeuedRuns());
            }
        } catch (Exception exception) {
            log.error("Agent runtime recovery failed", exception);
        }
    }
}
