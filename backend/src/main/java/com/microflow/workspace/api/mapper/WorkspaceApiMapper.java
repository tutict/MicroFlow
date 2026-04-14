package com.microflow.workspace.api.mapper;

import com.microflow.workspace.api.dto.ChannelSummaryResponse;
import com.microflow.workspace.api.dto.ConversationSummaryResponse;
import com.microflow.workspace.api.dto.WorkspaceMemberSummaryResponse;
import com.microflow.workspace.api.dto.WorkspaceSummaryResponse;
import com.microflow.workspace.domain.model.ChannelSummary;
import com.microflow.workspace.domain.model.ConversationSummary;
import com.microflow.workspace.domain.model.WorkspaceMemberSummary;
import com.microflow.workspace.domain.model.WorkspaceSummary;
import org.springframework.stereotype.Component;

@Component
public class WorkspaceApiMapper {

    public WorkspaceSummaryResponse toResponse(WorkspaceSummary workspace) {
        return new WorkspaceSummaryResponse(
                workspace.id(),
                workspace.name(),
                workspace.memberCount()
        );
    }

    public ChannelSummaryResponse toResponse(ChannelSummary channel) {
        return new ChannelSummaryResponse(
                channel.id(),
                channel.name(),
                channel.unreadCount()
        );
    }

    public ConversationSummaryResponse toResponse(ConversationSummary conversation) {
        return new ConversationSummaryResponse(
                conversation.id(),
                conversation.title(),
                conversation.subtitle(),
                conversation.kind().name(),
                conversation.unreadCount(),
                conversation.available(),
                conversation.lastActivityAt()
        );
    }

    public WorkspaceMemberSummaryResponse toResponse(WorkspaceMemberSummary member) {
        return new WorkspaceMemberSummaryResponse(
                member.userId(),
                member.email(),
                member.displayName(),
                member.role(),
                member.joinedAt()
        );
    }
}
