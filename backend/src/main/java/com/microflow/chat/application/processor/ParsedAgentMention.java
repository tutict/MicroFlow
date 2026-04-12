package com.microflow.chat.application.processor;

public record ParsedAgentMention(
        String agentKey,
        int startIndex,
        int endIndex
) {
}

