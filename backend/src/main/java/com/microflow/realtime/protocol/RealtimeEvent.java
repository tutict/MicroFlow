package com.microflow.realtime.protocol;

public record RealtimeEvent(
        String type,
        Object payload
) {
}

