package com.microflow.chat.api.ws;

import jakarta.validation.constraints.NotBlank;

public record SocketSubscribePayload(
        @NotBlank String channelId
) {
}

