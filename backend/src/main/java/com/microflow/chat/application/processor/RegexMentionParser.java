package com.microflow.chat.application.processor;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

@Component
public class RegexMentionParser implements MentionParser {

    private static final Pattern AGENT_PATTERN = Pattern.compile("@([a-zA-Z][a-zA-Z0-9_-]{1,31})");

    @Override
    public List<ParsedAgentMention> parse(String rawMessage) {
        var mentions = new LinkedHashMap<String, ParsedAgentMention>();
        Matcher matcher = AGENT_PATTERN.matcher(rawMessage);
        while (matcher.find()) {
            var mention = new ParsedAgentMention(
                    matcher.group(1).toLowerCase(),
                    matcher.start(),
                    matcher.end()
            );
            mentions.putIfAbsent(mention.agentKey(), mention);
        }
        return new ArrayList<>(mentions.values());
    }
}
