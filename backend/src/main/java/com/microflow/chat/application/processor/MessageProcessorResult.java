package com.microflow.chat.application.processor;

import java.util.List;

public record MessageProcessorResult(
        List<String> detectedAgents,
        List<String> queuedRunIds
) {

    public static MessageProcessorResult empty() {
        return new MessageProcessorResult(List.of(), List.of());
    }
}

