package com.microflow.agent.runtime.application;

import com.microflow.agent.runtime.domain.gateway.AgentTurnGateway;
import com.microflow.agent.runtime.domain.gateway.ProviderCapability;
import com.microflow.agent.runtime.infrastructure.persistence.JdbcAgentRuntimeRepository;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import org.springframework.stereotype.Service;

/**
 * Caches per-provider tool-call support.
 *
 * <p>The detection result is deliberately sticky for a day: probing on every run
 * would cost a request per turn. A probe failure is also cached as "unsupported",
 * because running without tools is the safe direction -- the alternative is
 * hoping a provider understands a shape it just rejected.
 */
@Service
public class ProviderCapabilityService {

    private static final Duration CACHE_TTL = Duration.ofHours(24);

    private final JdbcAgentRuntimeRepository runtimeRepository;
    private final AgentTurnGateway agentTurnGateway;
    private final Clock clock;

    public ProviderCapabilityService(
            JdbcAgentRuntimeRepository runtimeRepository,
            AgentTurnGateway agentTurnGateway,
            Clock clock
    ) {
        this.runtimeRepository = runtimeRepository;
        this.agentTurnGateway = agentTurnGateway;
        this.clock = clock;
    }

    public ProviderCapability resolve(String workspaceId, String agentKey) {
        var cached = runtimeRepository.findCapability(workspaceId, agentKey);
        if (cached.isPresent() && !isStale(cached.get())) {
            return cached.get();
        }
        var detected = agentTurnGateway.detectCapability(workspaceId, agentKey);
        runtimeRepository.upsertCapability(workspaceId, agentKey, detected);
        return detected;
    }

    public boolean supportsToolCalls(String workspaceId, String agentKey) {
        return resolve(workspaceId, agentKey).supportsToolCalls();
    }

    private boolean isStale(ProviderCapability capability) {
        if (capability.detectedAt() == null || capability.detectedAt().isBlank()) {
            return true;
        }
        try {
            var detectedAt = Instant.parse(capability.detectedAt());
            return !detectedAt.plus(CACHE_TTL).isAfter(Instant.now(clock));
        } catch (RuntimeException exception) {
            return true;
        }
    }
}
