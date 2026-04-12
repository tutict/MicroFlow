package com.microflow.realtime.broadcaster;

import com.microflow.realtime.protocol.RealtimeEvent;

public interface RealtimeBroadcaster {

    void publishToChannel(String channelId, RealtimeEvent event);

    void publishToUser(String userId, RealtimeEvent event);
}

