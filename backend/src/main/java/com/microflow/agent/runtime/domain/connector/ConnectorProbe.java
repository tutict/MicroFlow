package com.microflow.agent.runtime.domain.connector;

import com.microflow.agent.runtime.domain.model.AgentConnector;
import com.microflow.agent.runtime.domain.model.ConnectorKind;
import java.util.Map;

/**
 * A single, side-effect-free reachability check for a connector.
 *
 * <p>Probes answer "can this configuration be reached right now", not "is this
 * mailbox empty" -- MicroFlow never does a background crawl. Reaching the
 * server (and, where the protocol makes it cheap, completing the greeting
 * exchange) is enough for the settings screen to show a truthful status.
 */
public interface ConnectorProbe {

    boolean supports(ConnectorKind kind);

    ProbeOutcome test(AgentConnector connector, Map<String, String> credentials);

    /**
     * @param reachable whether the remote system answered as expected
     * @param detail    a short, secret-free sentence for the settings screen
     */
    record ProbeOutcome(boolean reachable, String detail) {

        public static ProbeOutcome ok(String detail) {
            return new ProbeOutcome(true, detail);
        }

        public static ProbeOutcome failed(String detail) {
            return new ProbeOutcome(false, detail);
        }
    }
}
