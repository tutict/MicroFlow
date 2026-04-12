package com.microflow.chat.api.ws;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SocketSendMessagePayload(
        @NotBlank String workspaceId,
        @NotBlank @Size(max = 4000) String content
) {
}
