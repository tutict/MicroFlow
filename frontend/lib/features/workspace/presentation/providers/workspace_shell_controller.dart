import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/realtime_socket_event.dart';
import '../../../../core/providers/app_providers.dart';
import '../../domain/entities/workspace_conversation.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/presentation/providers/auth_session_controller.dart';
import '../../../agents/domain/entities/agent_run.dart';
import '../../../chat/domain/entities/channel_summary.dart';
import '../../../chat/domain/entities/chat_message.dart';
import '../../../chat/presentation/state/chat_connection_status.dart';
import '../state/workspace_shell_state.dart';
import '../state/workspace_selected_conversation.dart';

final workspaceShellControllerProvider =
    AsyncNotifierProvider<WorkspaceShellController, WorkspaceShellState>(
      WorkspaceShellController.new,
    );

class WorkspaceShellController extends AsyncNotifier<WorkspaceShellState> {
  static const _emptyWorkspaceId = '';
  StreamSubscription<dynamic>? _socketSubscription;

  @override
  Future<WorkspaceShellState> build() async {
    ref.onDispose(() {
      _socketSubscription?.cancel();
    });

    final workspaceRepository = ref.read(workspaceRepositoryProvider);
    final chatRepository = ref.read(chatRepositoryProvider);
    final agentRepository = ref.read(agentRepositoryProvider);
    final session = await ref.watch(authSessionControllerProvider.future);
    if (session == null) {
      throw StateError('Not authenticated');
    }

    final workspaces = await workspaceRepository.listWorkspaces();
    if (workspaces.isEmpty) {
      return _buildFallbackState(
        session: session,
        workspaceId: _emptyWorkspaceId,
        workspaceName: 'MicroFlow',
      );
    }

    final workspace = workspaces.first;
    final channels = await workspaceRepository.listChannels(workspace.id);
    final conversations = await workspaceRepository.listConversations(
      workspace.id,
    );
    final agents = await agentRepository.listAgents(workspace.id);
    final agentRuns = await agentRepository.listRuns(workspace.id);
    final selectedConversation = _findInitialConversation(
      conversations,
      channels,
    );
    final messages = selectedConversation == null
        ? const <ChatMessage>[]
        : await chatRepository.listMessages(selectedConversation.id);

    final nextState = WorkspaceShellState(
      workspaceId: workspace.id,
      workspaceName: workspace.name,
      channels: channels,
      conversations: conversations,
      selectedConversation:
          selectedConversation ??
          WorkspaceSelectedConversation(
            id: '',
            title: workspace.name,
            kind: WorkspaceSelectedConversationKind.channel,
            isAvailable: false,
          ),
      messages: messages,
      agents: agents,
      agentRuns: agentRuns,
      connectionStatus: ChatConnectionStatus.idle,
      currentUserId: session.userId,
      currentUserLabel: session.displayName,
      isSendingMessage: false,
      collaborationModeByConversation: const {},
      collaborationStatusByConversation: const {},
    );
    if (workspace.id.isNotEmpty) {
      Future.microtask(() => connectRealtime(session.accessToken));
    }
    return nextState;
  }

  WorkspaceShellState _buildFallbackState({
    required AuthSession session,
    required String workspaceId,
    required String workspaceName,
  }) {
    return WorkspaceShellState(
      workspaceId: workspaceId,
      workspaceName: workspaceName,
      channels: const [],
      conversations: const [],
      selectedConversation: WorkspaceSelectedConversation(
        id: '',
        title: workspaceName,
        kind: WorkspaceSelectedConversationKind.channel,
        isAvailable: false,
      ),
      messages: const [],
      agents: const [],
      agentRuns: const [],
      connectionStatus: ChatConnectionStatus.idle,
      currentUserId: session.userId,
      currentUserLabel: session.displayName,
      isSendingMessage: false,
      collaborationModeByConversation: const {},
      collaborationStatusByConversation: const {},
    );
  }

  WorkspaceSelectedConversation? _findInitialConversation(
    List<WorkspaceConversation> conversations,
    List<ChannelSummary> channels,
  ) {
    if (channels.isNotEmpty) {
      final selectedChannel = channels.first;
      final selectedConversation = _findConversationById(
        conversations,
        selectedChannel.id,
      );
      return WorkspaceSelectedConversation(
        id: selectedConversation?.id ?? selectedChannel.id,
        title: selectedConversation?.title ?? selectedChannel.name,
        kind: WorkspaceSelectedConversationKind.channel,
        isAvailable: selectedConversation?.available ?? true,
      );
    }

    for (final conversation in conversations) {
      if (_isConversationChannelBacked(conversation)) {
        return WorkspaceSelectedConversation(
          id: conversation.id,
          title: conversation.title,
          kind: _mapConversationKind(conversation.kind),
          isAvailable: conversation.available,
        );
      }
    }

    return null;
  }

  WorkspaceSelectedConversationKind _mapConversationKind(String kind) {
    return switch (kind) {
      'DIRECT_MESSAGE' => WorkspaceSelectedConversationKind.directMessage,
      'AGENT_DM' => WorkspaceSelectedConversationKind.agentThread,
      _ => WorkspaceSelectedConversationKind.channel,
    };
  }

  bool _isConversationChannelBacked(WorkspaceConversation conversation) {
    return conversation.available &&
        (conversation.kind == 'CHANNEL' ||
            conversation.kind == 'DIRECT_MESSAGE' ||
            conversation.kind == 'AGENT_DM');
  }

  String _summarizePreview(String content) {
    final normalized = content.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= 72) {
      return normalized;
    }
    return '${normalized.substring(0, 72)}...';
  }

  List<WorkspaceConversation> _updateConversationActivity({
    required List<WorkspaceConversation> conversations,
    required String conversationId,
    required String preview,
    required String createdAt,
    required bool incrementUnread,
    required bool clearUnread,
  }) {
    return conversations
        .map((conversation) {
          if (conversation.id != conversationId) {
            return conversation;
          }
          return conversation.copyWith(
            subtitle: preview.isEmpty ? conversation.subtitle : preview,
            lastActivityAt: createdAt.isEmpty
                ? conversation.lastActivityAt
                : createdAt,
            unreadCount: clearUnread
                ? 0
                : incrementUnread
                ? conversation.unreadCount + 1
                : conversation.unreadCount,
          );
        })
        .toList(growable: false);
  }

  WorkspaceConversation? _findConversationById(
    List<WorkspaceConversation> conversations,
    String conversationId,
  ) {
    for (final conversation in conversations) {
      if (conversation.id == conversationId) {
        return conversation;
      }
    }
    return null;
  }

  Future<void> selectConversation({
    required String conversationId,
    required String title,
    required WorkspaceSelectedConversationKind kind,
    required bool isAvailable,
  }) async {
    final current = state.valueOrNull;
    if (current == null ||
        (current.selectedConversationId == conversationId &&
            current.selectedConversation.kind == kind)) {
      return;
    }

    if ((kind == WorkspaceSelectedConversationKind.channel && isAvailable) ||
        (kind == WorkspaceSelectedConversationKind.directMessage &&
            isAvailable) ||
        (kind == WorkspaceSelectedConversationKind.agentThread &&
            isAvailable)) {
      final messages = await ref
          .read(chatRepositoryProvider)
          .listMessages(conversationId);
      final latestMessage = messages.isEmpty ? null : messages.last;
      state = AsyncData(
        current.copyWith(
          conversations: _updateConversationActivity(
            conversations: current.conversations,
            conversationId: conversationId,
            preview: latestMessage == null
                ? ''
                : _summarizePreview(latestMessage.text),
            createdAt: latestMessage?.createdAt ?? '',
            incrementUnread: false,
            clearUnread: true,
          ),
          selectedConversation: WorkspaceSelectedConversation(
            id: conversationId,
            title: title,
            kind: kind,
            isAvailable: isAvailable,
          ),
          messages: messages,
          clearMessageError: true,
        ),
      );
      await _subscribeChannel(conversationId);
      return;
    }

    state = AsyncData(
      current.copyWith(
        selectedConversation: WorkspaceSelectedConversation(
          id: conversationId,
          title: title,
          kind: kind,
          isAvailable: isAvailable,
        ),
        messages: const [],
        isSendingMessage: false,
        clearMessageError: true,
      ),
    );
  }

  Future<void> selectChannel(ChannelSummary channel) async {
    await selectConversation(
      conversationId: channel.id,
      title: channel.name,
      kind: WorkspaceSelectedConversationKind.channel,
      isAvailable: true,
    );
  }

  Future<void> sendMessage(String rawContent) async {
    final content = rawContent.trim();
    final current = state.valueOrNull;
    if (current == null || content.isEmpty || current.isSendingMessage) {
      return;
    }

    final selectedChannelId = current.selectedChannelIdOrNull;
    if (selectedChannelId == null) {
      state = AsyncData(
        current.copyWith(
          isSendingMessage: false,
          messageError: 'Selected conversation is not backed by a channel yet.',
        ),
      );
      return;
    }

    final outboundContent = _prepareOutboundContent(current, content);
    state = AsyncData(
      current.copyWith(isSendingMessage: true, clearMessageError: true),
    );

    try {
      if (current.connectionStatus == ChatConnectionStatus.connected) {
        await ref
            .read(realtimeSocketServiceProvider)
            .sendMessage(
              workspaceId: current.workspaceId,
              channelId: selectedChannelId,
              content: outboundContent,
            );
        final latest = state.valueOrNull;
        if (latest != null) {
          state = AsyncData(
            latest.copyWith(isSendingMessage: false, clearMessageError: true),
          );
        }
        return;
      }

      final createdMessage = await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            workspaceId: current.workspaceId,
            channelId: selectedChannelId,
            senderUserId: current.currentUserId,
            content: outboundContent,
          );

      final latest = state.valueOrNull;
      if (latest != null) {
        state = AsyncData(
          latest.copyWith(
            messages: [...latest.messages, createdMessage],
            conversations: _updateConversationActivity(
              conversations: latest.conversations,
              conversationId: selectedChannelId,
              preview: _summarizePreview(createdMessage.text),
              createdAt: createdMessage.createdAt,
              incrementUnread: false,
              clearUnread: true,
            ),
            isSendingMessage: false,
            clearMessageError: true,
          ),
        );
      }
    } catch (error) {
      final latest = state.valueOrNull;
      if (latest != null) {
        state = AsyncData(
          latest.copyWith(
            isSendingMessage: false,
            messageError: error.toString(),
          ),
        );
      }
    }
  }

  Future<void> connectRealtime(String token) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(
      current.copyWith(connectionStatus: ChatConnectionStatus.connecting),
    );
    final socketService = ref.read(realtimeSocketServiceProvider);

    try {
      await socketService.connect(token: token);
      _socketSubscription?.cancel();
      _socketSubscription = socketService.rawEvents.listen(_handleSocketEvent);
      state = AsyncData(
        current.copyWith(connectionStatus: ChatConnectionStatus.connected),
      );
      for (final conversation in current.conversations) {
        if (_isConversationChannelBacked(conversation)) {
          await _subscribeChannel(conversation.id);
        }
      }
    } catch (_) {
      final latest = state.valueOrNull;
      if (latest != null) {
        state = AsyncData(
          latest.copyWith(connectionStatus: ChatConnectionStatus.error),
        );
      }
    }
  }

  Future<void> disconnectRealtime() async {
    final current = state.valueOrNull;
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await ref.read(realtimeSocketServiceProvider).disconnect();
    if (current != null) {
      state = AsyncData(
        current.copyWith(connectionStatus: ChatConnectionStatus.disconnected),
      );
    }
  }

  Future<void> _subscribeChannel(String channelId) async {
    final current = state.valueOrNull;
    if (current == null ||
        current.connectionStatus != ChatConnectionStatus.connected) {
      return;
    }
    await ref.read(realtimeSocketServiceProvider).subscribe(channelId);
  }

  void setCollaborationModeForSelectedConversation(bool enabled) {
    final current = state.valueOrNull;
    if (current == null ||
        current.selectedConversation.kind !=
            WorkspaceSelectedConversationKind.channel) {
      return;
    }
    final nextModes = Map<String, bool>.from(
      current.collaborationModeByConversation,
    );
    nextModes[current.selectedConversation.id] = enabled;
    state = AsyncData(
      current.copyWith(collaborationModeByConversation: nextModes),
    );
  }

  String _prepareOutboundContent(WorkspaceShellState current, String content) {
    if (current.selectedConversation.kind !=
            WorkspaceSelectedConversationKind.channel ||
        !current.isCollaborationEnabledForSelectedConversation) {
      return content;
    }
    final normalized = content.toLowerCase();
    if (normalized.contains('@team') || normalized.contains('@all-agents')) {
      return content;
    }
    return '@team $content';
  }

  WorkspaceShellState _mergeCollaborationStatus(
    WorkspaceShellState current,
    Map<String, Object?> payload, {
    String? fallbackStatus,
  }) {
    final channelId = payload['channelId'] as String?;
    if (channelId == null || channelId.isEmpty) {
      return current;
    }
    final existing = current.collaborationStatusByConversation[channelId];
    final nextStatus = CollaborationStatusSnapshot(
      collaborationId:
          payload['collaborationId'] as String? ??
          existing?.collaborationId ??
          'collaboration',
      status:
          payload['status'] as String? ??
          fallbackStatus ??
          existing?.status ??
          'RUNNING',
      trigger: payload['trigger'] as String? ?? existing?.trigger ?? '@team',
      round: (payload['round'] as num?)?.toInt() ?? existing?.round ?? 0,
      maxRounds:
          (payload['maxRounds'] as num?)?.toInt() ?? existing?.maxRounds ?? 0,
      activeAgentKey:
          payload['agentKey'] as String? ?? existing?.activeAgentKey,
      detail:
          payload['detail'] as String? ??
          payload['reason'] as String? ??
          existing?.detail,
    );
    final nextStatuses = Map<String, CollaborationStatusSnapshot>.from(
      current.collaborationStatusByConversation,
    );
    nextStatuses[channelId] = nextStatus;
    return current.copyWith(collaborationStatusByConversation: nextStatuses);
  }

  void _handleSocketEvent(dynamic rawEvent) {
    final current = state.valueOrNull;
    if (current == null || rawEvent is! Map<String, Object?>) {
      return;
    }
    final event = RealtimeSocketEvent.fromJson(rawEvent);

    switch (event.type) {
      case RealtimeSocketEventType.messageCreated:
        final payload = event.payload;
        if (payload == null) {
          return;
        }
        final eventChannelId = payload['channelId'] as String?;
        if (eventChannelId == null) {
          return;
        }
        final message = ChatMessage(
          id: payload['id'] as String? ?? 'remote',
          author: payload['senderUserId'] as String? ?? 'agent',
          text: payload['content'] as String? ?? '',
          createdAt: payload['createdAt'] as String? ?? '',
          isAgent: (payload['senderUserId'] as String? ?? '').startsWith(
            'agent:',
          ),
        );
        final isCurrentConversation =
            eventChannelId == current.selectedChannelIdOrNull;
        final isOwnMessage = message.author == current.currentUserId;
        state = AsyncData(
          current.copyWith(
            conversations: _updateConversationActivity(
              conversations: current.conversations,
              conversationId: eventChannelId,
              preview: _summarizePreview(message.text),
              createdAt: message.createdAt,
              incrementUnread: !isCurrentConversation && !isOwnMessage,
              clearUnread: isCurrentConversation,
            ),
            messages: isCurrentConversation
                ? [...current.messages, message]
                : current.messages,
          ),
        );
        return;
      case RealtimeSocketEventType.agentRunCreated:
      case RealtimeSocketEventType.agentRunUpdated:
        final payload = event.payload;
        if (payload == null) {
          return;
        }
        final runId = payload['runId'] as String? ?? 'run';
        final existingRunIndex = current.agentRuns.indexWhere(
          (candidate) => candidate.id == runId,
        );
        final existingRun = existingRunIndex >= 0
            ? current.agentRuns[existingRunIndex]
            : null;
        final run = AgentRun(
          id: runId,
          agentKey:
              payload['agentKey'] as String? ??
              existingRun?.agentKey ??
              'agent',
          status: payload['status'] as String? ?? 'UNKNOWN',
        );
        final nextRuns = [...current.agentRuns];
        final nextRunIndex = nextRuns.indexWhere(
          (candidate) => candidate.id == run.id,
        );
        if (nextRunIndex >= 0) {
          nextRuns[nextRunIndex] = run;
        } else {
          nextRuns.insert(0, run);
        }
        state = AsyncData(current.copyWith(agentRuns: nextRuns));
        return;
      case RealtimeSocketEventType.collaborationStarted:
        final payload = event.payload;
        if (payload == null) {
          return;
        }
        state = AsyncData(
          _mergeCollaborationStatus(
            current,
            payload,
            fallbackStatus: 'RUNNING',
          ),
        );
        return;
      case RealtimeSocketEventType.collaborationStep:
        final payload = event.payload;
        if (payload == null) {
          return;
        }
        state = AsyncData(_mergeCollaborationStatus(current, payload));
        return;
      case RealtimeSocketEventType.collaborationCompleted:
        final payload = event.payload;
        if (payload == null) {
          return;
        }
        state = AsyncData(
          _mergeCollaborationStatus(
            current,
            payload,
            fallbackStatus: 'COMPLETED',
          ),
        );
        return;
      case RealtimeSocketEventType.collaborationAborted:
        final payload = event.payload;
        if (payload == null) {
          return;
        }
        state = AsyncData(
          _mergeCollaborationStatus(
            current,
            payload,
            fallbackStatus: 'ABORTED',
          ),
        );
        return;
      case RealtimeSocketEventType.subscribed:
      case RealtimeSocketEventType.error:
      case RealtimeSocketEventType.unknown:
        return;
    }
  }
}
