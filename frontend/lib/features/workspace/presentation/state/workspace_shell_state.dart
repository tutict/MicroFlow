import '../../../agents/domain/entities/agent_descriptor.dart';
import '../../../agents/domain/entities/agent_run.dart';
import '../../../chat/domain/entities/channel_summary.dart';
import '../../../chat/domain/entities/chat_message.dart';
import '../../domain/entities/workspace_conversation.dart';
import '../../../chat/presentation/state/chat_connection_status.dart';
import 'workspace_selected_conversation.dart';

class WorkspaceShellState {
  const WorkspaceShellState({
    required this.workspaceId,
    required this.workspaceName,
    required this.channels,
    required this.conversations,
    required this.selectedConversation,
    required this.messages,
    required this.agents,
    required this.agentRuns,
    required this.connectionStatus,
    required this.currentUserId,
    required this.currentUserLabel,
    required this.isSendingMessage,
    required this.collaborationModeByConversation,
    required this.collaborationStatusByConversation,
    this.messageError,
  });

  final String workspaceId;
  final String workspaceName;
  final List<ChannelSummary> channels;
  final List<WorkspaceConversation> conversations;
  final WorkspaceSelectedConversation selectedConversation;
  final List<ChatMessage> messages;
  final List<AgentDescriptor> agents;
  final List<AgentRun> agentRuns;
  final ChatConnectionStatus connectionStatus;
  final String currentUserId;
  final String currentUserLabel;
  final bool isSendingMessage;
  final Map<String, bool> collaborationModeByConversation;
  final Map<String, CollaborationStatusSnapshot>
  collaborationStatusByConversation;
  final String? messageError;

  String get selectedConversationId => selectedConversation.id;

  String? get selectedChannelIdOrNull =>
      selectedConversation.isChannelBacked ? selectedConversation.id : null;

  bool get isCollaborationEnabledForSelectedConversation =>
      collaborationModeByConversation[selectedConversation.id] ?? false;

  CollaborationStatusSnapshot? get selectedCollaborationStatus =>
      collaborationStatusByConversation[selectedConversation.id];

  WorkspaceShellState copyWith({
    String? workspaceId,
    String? workspaceName,
    List<ChannelSummary>? channels,
    List<WorkspaceConversation>? conversations,
    WorkspaceSelectedConversation? selectedConversation,
    List<ChatMessage>? messages,
    List<AgentDescriptor>? agents,
    List<AgentRun>? agentRuns,
    ChatConnectionStatus? connectionStatus,
    String? currentUserId,
    String? currentUserLabel,
    bool? isSendingMessage,
    Map<String, bool>? collaborationModeByConversation,
    Map<String, CollaborationStatusSnapshot>? collaborationStatusByConversation,
    String? messageError,
    bool clearMessageError = false,
  }) {
    return WorkspaceShellState(
      workspaceId: workspaceId ?? this.workspaceId,
      workspaceName: workspaceName ?? this.workspaceName,
      channels: channels ?? this.channels,
      conversations: conversations ?? this.conversations,
      selectedConversation: selectedConversation ?? this.selectedConversation,
      messages: messages ?? this.messages,
      agents: agents ?? this.agents,
      agentRuns: agentRuns ?? this.agentRuns,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      currentUserId: currentUserId ?? this.currentUserId,
      currentUserLabel: currentUserLabel ?? this.currentUserLabel,
      isSendingMessage: isSendingMessage ?? this.isSendingMessage,
      collaborationModeByConversation:
          collaborationModeByConversation ??
          this.collaborationModeByConversation,
      collaborationStatusByConversation:
          collaborationStatusByConversation ??
          this.collaborationStatusByConversation,
      messageError: clearMessageError
          ? null
          : messageError ?? this.messageError,
    );
  }
}

class CollaborationStatusSnapshot {
  const CollaborationStatusSnapshot({
    required this.collaborationId,
    required this.status,
    required this.trigger,
    required this.round,
    required this.maxRounds,
    this.activeAgentKey,
    this.detail,
  });

  final String collaborationId;
  final String status;
  final String trigger;
  final int round;
  final int maxRounds;
  final String? activeAgentKey;
  final String? detail;

  CollaborationStatusSnapshot copyWith({
    String? collaborationId,
    String? status,
    String? trigger,
    int? round,
    int? maxRounds,
    String? activeAgentKey,
    String? detail,
  }) {
    return CollaborationStatusSnapshot(
      collaborationId: collaborationId ?? this.collaborationId,
      status: status ?? this.status,
      trigger: trigger ?? this.trigger,
      round: round ?? this.round,
      maxRounds: maxRounds ?? this.maxRounds,
      activeAgentKey: activeAgentKey ?? this.activeAgentKey,
      detail: detail ?? this.detail,
    );
  }
}
