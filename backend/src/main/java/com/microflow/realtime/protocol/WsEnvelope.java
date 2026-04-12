package com.microflow.realtime.protocol;

public record WsEnvelope(
        String type,
        String requestId,
        String channelId,
        Object payload
) {
}

