package com.microflow.chat.application.processor;

import java.util.List;

public interface MentionParser {

    List<ParsedAgentMention> parse(String rawMessage);
}

