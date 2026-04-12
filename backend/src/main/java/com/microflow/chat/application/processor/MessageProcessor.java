package com.microflow.chat.application.processor;

import com.microflow.chat.domain.model.ChatMessage;

public interface MessageProcessor {

    MessageProcessorResult process(ChatMessage message);
}

