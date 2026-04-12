package com.microflow.bootstrap;

import com.microflow.agent.domain.model.AgentExecutionRequest;
import com.microflow.agent.domain.model.AgentExecutionResult;
import com.microflow.auth.api.dto.LoginRequest;
import com.microflow.auth.api.dto.RegisterRequest;
import com.microflow.chat.api.dto.SendMessageRequest;
import com.microflow.chat.api.ws.SocketSendMessagePayload;
import com.microflow.chat.api.ws.SocketSubscribePayload;
import com.microflow.common.crypto.EncryptedPayload;
import com.microflow.realtime.protocol.RealtimeEvent;
import com.microflow.realtime.protocol.WsEnvelope;
import org.springframework.aot.hint.MemberCategory;
import org.springframework.aot.hint.RuntimeHints;
import org.springframework.aot.hint.RuntimeHintsRegistrar;

public final class MicroFlowRuntimeHints implements RuntimeHintsRegistrar {

    @Override
    public void registerHints(RuntimeHints hints, ClassLoader classLoader) {
        hints.reflection().registerType(WsEnvelope.class, MemberCategory.INVOKE_DECLARED_CONSTRUCTORS, MemberCategory.INVOKE_PUBLIC_METHODS);
        hints.reflection().registerType(RealtimeEvent.class, MemberCategory.INVOKE_DECLARED_CONSTRUCTORS, MemberCategory.INVOKE_PUBLIC_METHODS);
        hints.reflection().registerType(EncryptedPayload.class, MemberCategory.INVOKE_DECLARED_CONSTRUCTORS, MemberCategory.INVOKE_PUBLIC_METHODS);
        hints.reflection().registerType(AgentExecutionRequest.class, MemberCategory.INVOKE_DECLARED_CONSTRUCTORS, MemberCategory.INVOKE_PUBLIC_METHODS);
        hints.reflection().registerType(AgentExecutionResult.class, MemberCategory.INVOKE_DECLARED_CONSTRUCTORS, MemberCategory.INVOKE_PUBLIC_METHODS);
        hints.reflection().registerType(LoginRequest.class, MemberCategory.INVOKE_DECLARED_CONSTRUCTORS, MemberCategory.INVOKE_PUBLIC_METHODS);
        hints.reflection().registerType(RegisterRequest.class, MemberCategory.INVOKE_DECLARED_CONSTRUCTORS, MemberCategory.INVOKE_PUBLIC_METHODS);
        hints.reflection().registerType(SendMessageRequest.class, MemberCategory.INVOKE_DECLARED_CONSTRUCTORS, MemberCategory.INVOKE_PUBLIC_METHODS);
        hints.reflection().registerType(SocketSendMessagePayload.class, MemberCategory.INVOKE_DECLARED_CONSTRUCTORS, MemberCategory.INVOKE_PUBLIC_METHODS);
        hints.reflection().registerType(SocketSubscribePayload.class, MemberCategory.INVOKE_DECLARED_CONSTRUCTORS, MemberCategory.INVOKE_PUBLIC_METHODS);
    }
}
