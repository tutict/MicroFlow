package com.microflow.agent.runtime.domain.gateway;

/** Whether a provider can emit structured tool calls, as detected (not assumed). */
public record ProviderCapability(
        boolean supportsToolCalls,
        String detail,
        String detectedAt
) {

    public static ProviderCapability unsupported(String detail, String detectedAt) {
        return new ProviderCapability(false, detail, detectedAt);
    }
}
