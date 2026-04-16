import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/realtime_socket_event.dart';
import '../../../../core/providers/app_providers.dart';
import '../../domain/entities/workspace_summary.dart';
import '../../domain/entities/workspace_conversation.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/presentation/providers/auth_session_controller.dart';
import '../../../agents/domain/entities/agent_run.dart';
import '../../../chat/domain/entities/channel_summary.dart';
import '../../../chat/domain/entities/chat_message.dart';
import '../../../chat/domain/entities/collaboration_event.dart';
import '../../../chat/domain/entities/collaboration_run.dart';
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
  final Map<String, WorkspaceShellState> _workspaceCache = {};

  @override
  Future<WorkspaceShellState> build() async {
    ref.onDispose(() {
      _socketSubscription?.cancel();
    });

    final workspaceRepository = ref.read(workspaceRepositoryProvider);
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

    final nextState = await _buildWorkspaceState(
      session: session,
      workspaces: workspaces,
      workspace: workspaces.first,
    );
    _cacheWorkspaceState(nextState);
    if (nextState.workspaceId.isNotEmpty) {
      Future.microtask(() => connectRealtime(session.accessToken));
    }
    return nextState;
  }

  Future<WorkspaceShellState> _buildWorkspaceState({
    required AuthSession session,
    required List<WorkspaceSummary> workspaces,
    required WorkspaceSummary workspace,
  }) async {
    final workspaceRepository = ref.read(workspaceRepositoryProvider);
    final chatRepository = ref.read(chatRepositoryProvider);
    final agentRepository = ref.read(agentRepositoryProvider);
    final channels = await workspaceRepository.listChannels(workspace.id);
    final conversations = await workspaceRepository.listConversations(
      workspace.id,
    );
    final members = await workspaceRepository.listMembers(workspace.id);
    final knowledgeDocuments = await workspaceRepository.listKnowledgeDocuments(
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
    final collaborationRuns =
        selectedConversation == null || !selectedConversation.isChannelBacked
        ? const <CollaborationRun>[]
        : await chatRepository.listCollaborationRuns(selectedConversation.id);

    final nextState = WorkspaceShellState(
      workspaceId: workspace.id,
      workspaceName: workspace.name,
      channels: channels,
      conversations: conversations,
      workspaces: workspaces,
      workspaceMembers: members,
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
      collaborationRunsByConversation: selectedConversation == null
          ? const {}
          : {selectedConversation.id: collaborationRuns},
      knowledgeDocuments: knowledgeDocuments,
    );
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
      workspaces: const [],
      workspaceMembers: const [],
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
      collaborationRunsByConversation: const {},
      knowledgeDocuments: const [],
    );
  }

  void _cacheWorkspaceState(WorkspaceShellState nextState) {
    if (nextState.workspaceId.isEmpty) {
      return;
    }
    _workspaceCache[nextState.workspaceId] = nextState;
  }

  void _setWorkspaceState(WorkspaceShellState nextState) {
    _cacheWorkspaceState(nextState);
    state = AsyncData(nextState);
  }

  void _propagateWorkspaceDirectory(List<WorkspaceSummary> workspaces) {
    if (_workspaceCache.isEmpty) {
      return;
    }
    final entries = _workspaceCache.entries.toList(growable: false);
    for (final entry in entries) {
      _workspaceCache[entry.key] = entry.value.copyWith(workspaces: workspaces);
    }
  }

  WorkspaceShellState _hydrateCachedState({
    required WorkspaceShellState cached,
    required WorkspaceShellState current,
    required AuthSession session,
  }) {
    return cached.copyWith(
      workspaces: current.workspaces,
      connectionStatus: current.connectionStatus,
      currentUserId: session.userId,
      currentUserLabel: session.displayName,
    );
  }

  Future<void> selectWorkspace(String workspaceId) async {
    final current = state.valueOrNull;
    if (current == null ||
        workspaceId.isEmpty ||
        workspaceId == current.workspaceId) {
      return;
    }
    WorkspaceSummary? target;
    for (final workspace in current.workspaces) {
      if (workspace.id == workspaceId) {
        target = workspace;
        break;
      }
    }
    if (target == null) {
      return;
    }
    final session = await ref.read(authSessionControllerProvider.future);
    if (session == null) {
      return;
    }
    final cached = _workspaceCache[workspaceId];
    if (cached != null) {
      final hydrated = _hydrateCachedState(
        cached: cached,
        current: current,
        session: session,
      );
      _setWorkspaceState(hydrated);
      if (current.connectionStatus == ChatConnectionStatus.connected) {
        for (final conversation in hydrated.conversations) {
          if (_isConversationChannelBacked(conversation)) {
            await _subscribeChannel(conversation.id);
          }
        }
      }
      return;
    }
    state = const AsyncLoading();
    final nextState = await _buildWorkspaceState(
      session: session,
      workspaces: current.workspaces,
      workspace: target,
    );
    _setWorkspaceState(
      nextState.copyWith(connectionStatus: current.connectionStatus),
    );
    if (current.connectionStatus == ChatConnectionStatus.connected) {
      for (final conversation in nextState.conversations) {
        if (_isConversationChannelBacked(conversation)) {
          await _subscribeChannel(conversation.id);
        }
      }
    }
  }

  Future<void> createWorkspace(String name) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return;
    }
    final repository = ref.read(workspaceRepositoryProvider);
    final created = await repository.createWorkspace(normalizedName);
    final nextWorkspaces = [created, ...current.workspaces];
    _propagateWorkspaceDirectory(nextWorkspaces);
    final session = await ref.read(authSessionControllerProvider.future);
    if (session == null) {
      return;
    }
    state = const AsyncLoading();
    final nextState = await _buildWorkspaceState(
      session: session,
      workspaces: nextWorkspaces,
      workspace: created,
    );
    _setWorkspaceState(nextState);
    await connectRealtime(session.accessToken);
  }

  Future<void> refreshKnowledgeDocuments() async {
    final current = state.valueOrNull;
    if (current == null || current.workspaceId.isEmpty) {
      return;
    }
    try {
      final documents = await ref
          .read(workspaceRepositoryProvider)
          .listKnowledgeDocuments(current.workspaceId);
      _setWorkspaceState(
        current.copyWith(
          knowledgeDocuments: documents,
          clearKnowledgeError: true,
        ),
      );
    } catch (error) {
      _setWorkspaceState(current.copyWith(knowledgeError: error.toString()));
    }
  }

  Future<void> addMemberByEmail(String email) async {
    final current = state.valueOrNull;
    if (current == null || current.workspaceId.isEmpty) {
      return;
    }
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      return;
    }
    try {
      final members = await ref
          .read(workspaceRepositoryProvider)
          .addMemberByEmail(
            workspaceId: current.workspaceId,
            email: normalizedEmail,
          );
      _setWorkspaceState(
        current.copyWith(workspaceMembers: members, clearMessageError: true),
      );
    } catch (error) {
      _setWorkspaceState(current.copyWith(messageError: error.toString()));
    }
  }

  Future<void> uploadKnowledgeDocument({
    required String fileName,
    required Uint8List bytes,
    String? channelId,
    bool inheritSelectedConversation = true,
  }) async {
    final current = state.valueOrNull;
    if (current == null || current.workspaceId.isEmpty) {
      return;
    }
    _setWorkspaceState(
      current.copyWith(
        isUploadingKnowledgeDocument: true,
        clearKnowledgeError: true,
      ),
    );
    try {
      final document = await ref
          .read(workspaceRepositoryProvider)
          .uploadKnowledgeDocument(
            workspaceId: current.workspaceId,
            fileName: fileName,
            bytes: bytes,
            channelId: inheritSelectedConversation
                ? channelId ?? current.selectedChannelIdOrNull
                : channelId,
          );
      final latest = state.valueOrNull ?? current;
      _setWorkspaceState(
        latest.copyWith(
          isUploadingKnowledgeDocument: false,
          knowledgeDocuments: [document, ...latest.knowledgeDocuments],
          clearKnowledgeError: true,
        ),
      );
    } catch (error) {
      final latest = state.valueOrNull ?? current;
      _setWorkspaceState(
        latest.copyWith(
          isUploadingKnowledgeDocument: false,
          knowledgeError: error.toString(),
        ),
      );
    }
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
      final chatRepository = ref.read(chatRepositoryProvider);
      final messages = await chatRepository.listMessages(conversationId);
      final collaborationRuns = await chatRepository.listCollaborationRuns(
        conversationId,
      );
      final latestMessage = messages.isEmpty ? null : messages.last;
      _setWorkspaceState(
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
          collaborationRunsByConversation: {
            ...current.collaborationRunsByConversation,
            conversationId: collaborationRuns,
          },
          clearMessageError: true,
        ),
      );
      await _subscribeChannel(conversationId);
      return;
    }

    _setWorkspaceState(
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
      _setWorkspaceState(
        current.copyWith(
          isSendingMessage: false,
          messageError: 'Selected conversation is not backed by a channel yet.',
        ),
      );
      return;
    }

    final outboundContent = _prepareOutboundContent(current, content);
    _setWorkspaceState(
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
          _setWorkspaceState(
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
        _setWorkspaceState(
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
        _setWorkspaceState(
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

    _setWorkspaceState(
      current.copyWith(connectionStatus: ChatConnectionStatus.connecting),
    );
    final socketService = ref.read(realtimeSocketServiceProvider);

    try {
      await socketService.connect(token: token);
      _socketSubscription?.cancel();
      _socketSubscription = socketService.rawEvents.listen(_handleSocketEvent);
      _setWorkspaceState(
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
        _setWorkspaceState(
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
      _setWorkspaceState(
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
    _setWorkspaceState(
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
    final round = (payload['round'] as num?)?.toInt() ?? existing?.round ?? 0;
    final maxRounds =
        (payload['maxRounds'] as num?)?.toInt() ?? existing?.maxRounds ?? 0;
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
      round: round,
      maxRounds: maxRounds,
      stage:
          payload['stage'] as String? ??
          _inferCollaborationStage(round: round, maxRounds: maxRounds) ??
          existing?.stage,
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

  WorkspaceShellState _appendCollaborationRun(
    WorkspaceShellState current,
    Map<String, Object?> payload, {
    String? fallbackStatus,
  }) {
    final channelId = payload['channelId'] as String?;
    if (channelId == null || channelId.isEmpty) {
      return current;
    }
    final existingStatus = current.collaborationStatusByConversation[channelId];
    final round =
        (payload['round'] as num?)?.toInt() ?? existingStatus?.round ?? 0;
    final maxRounds =
        (payload['maxRounds'] as num?)?.toInt() ??
        existingStatus?.maxRounds ??
        0;
    final status =
        payload['status'] as String? ??
        fallbackStatus ??
        existingStatus?.status ??
        'RUNNING';
    final stage =
        payload['stage'] as String? ??
        _inferCollaborationStage(round: round, maxRounds: maxRounds) ??
        existingStatus?.stage;
    final nextEntry = CollaborationEvent(
      id:
          payload['eventId'] as String? ??
          'evt_${DateTime.now().microsecondsSinceEpoch}',
      workspaceId: payload['workspaceId'] as String? ?? current.workspaceId,
      channelId: channelId,
      collaborationId:
          payload['collaborationId'] as String? ??
          existingStatus?.collaborationId ??
          'collaboration',
      eventType:
          payload['eventType'] as String? ??
          'COLLABORATION_${status.toUpperCase()}',
      status: status,
      round: round,
      maxRounds: maxRounds,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      stage: stage,
      trigger:
          payload['trigger'] as String? ??
          existingStatus?.trigger ??
          current.selectedCollaborationStatus?.trigger,
      agentKey:
          payload['agentKey'] as String? ?? existingStatus?.activeAgentKey,
      detail:
          payload['detail'] as String? ??
          payload['reason'] as String? ??
          existingStatus?.detail,
    );
    final nextRuns = Map<String, List<CollaborationRun>>.from(
      current.collaborationRunsByConversation,
    );
    final channelRuns = [...?nextRuns[channelId]];
    final collaborationId = nextEntry.collaborationId;
    final existingRunIndex = channelRuns.indexWhere(
      (candidate) => candidate.collaborationId == collaborationId,
    );
    if (existingRunIndex >= 0) {
      final existingRun = channelRuns[existingRunIndex];
      final updatedEvents = [...existingRun.events, nextEntry];
      channelRuns[existingRunIndex] = existingRun.copyWith(
        status: nextEntry.status,
        triggerMessageId:
            payload['triggerMessageId'] as String? ??
            existingRun.triggerMessageId,
        stage: nextEntry.stage,
        activeAgentKey: nextEntry.agentKey ?? existingRun.activeAgentKey,
        agentKeys: _mergeAgentKeys(
          existingRun.agentKeys,
          payload['agentKeys'],
          nextEntry.agentKey,
        ),
        trigger: nextEntry.trigger ?? existingRun.trigger,
        reason:
            payload['reason'] as String? ??
            nextEntry.detail ??
            existingRun.reason,
        round: nextEntry.round,
        maxRounds: nextEntry.maxRounds,
        detail: nextEntry.detail ?? existingRun.detail,
        lastEventAt: nextEntry.createdAt,
        events: updatedEvents.length > 12
            ? updatedEvents.sublist(updatedEvents.length - 12)
            : updatedEvents,
      );
      final updatedRun = channelRuns.removeAt(existingRunIndex);
      channelRuns.insert(0, updatedRun);
    } else {
      channelRuns.insert(
        0,
        CollaborationRun(
          collaborationId: collaborationId,
          workspaceId: nextEntry.workspaceId,
          channelId: nextEntry.channelId,
          status: nextEntry.status,
          round: nextEntry.round,
          maxRounds: nextEntry.maxRounds,
          startedAt: nextEntry.createdAt,
          lastEventAt: nextEntry.createdAt,
          triggerMessageId: payload['triggerMessageId'] as String?,
          stage: nextEntry.stage,
          activeAgentKey: nextEntry.agentKey,
          agentKeys: _mergeAgentKeys(
            const [],
            payload['agentKeys'],
            nextEntry.agentKey,
          ),
          trigger: nextEntry.trigger,
          reason: payload['reason'] as String? ?? nextEntry.detail,
          detail: nextEntry.detail,
          events: [nextEntry],
        ),
      );
    }
    nextRuns[channelId] = channelRuns.length > 12
        ? channelRuns.sublist(0, 12)
        : channelRuns;
    return current.copyWith(collaborationRunsByConversation: nextRuns);
  }

  List<String> _mergeAgentKeys(
    List<String> existing,
    Object? rawAgentKeys,
    String? fallbackAgentKey,
  ) {
    final ordered = <String>{...existing};
    if (rawAgentKeys is List) {
      for (final candidate in rawAgentKeys) {
        if (candidate is String && candidate.trim().isNotEmpty) {
          ordered.add(candidate.trim());
        }
      }
    }
    if (fallbackAgentKey != null && fallbackAgentKey.trim().isNotEmpty) {
      ordered.add(fallbackAgentKey.trim());
    }
    return ordered.toList(growable: false);
  }

  String? _inferCollaborationStage({
    required int round,
    required int maxRounds,
  }) {
    if (round <= 0 || maxRounds <= 0) {
      return null;
    }
    if (maxRounds == 1) {
      return 'deliver';
    }
    if (round == 1) {
      return 'analyze';
    }
    if (round >= maxRounds) {
      return 'synthesize';
    }
    return 'critique';
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
        _setWorkspaceState(
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
        _setWorkspaceState(current.copyWith(agentRuns: nextRuns));
        return;
      case RealtimeSocketEventType.collaborationStarted:
        final payload = event.payload;
        if (payload == null) {
          return;
        }
        final nextState = _appendCollaborationRun(
          _mergeCollaborationStatus(
            current,
            payload,
            fallbackStatus: 'RUNNING',
          ),
          payload,
          fallbackStatus: 'RUNNING',
        );
        _setWorkspaceState(nextState);
        return;
      case RealtimeSocketEventType.collaborationStep:
        final payload = event.payload;
        if (payload == null) {
          return;
        }
        final nextState = _appendCollaborationRun(
          _mergeCollaborationStatus(current, payload),
          payload,
        );
        _setWorkspaceState(nextState);
        return;
      case RealtimeSocketEventType.collaborationCompleted:
        final payload = event.payload;
        if (payload == null) {
          return;
        }
        final nextState = _appendCollaborationRun(
          _mergeCollaborationStatus(
            current,
            payload,
            fallbackStatus: 'COMPLETED',
          ),
          payload,
          fallbackStatus: 'COMPLETED',
        );
        _setWorkspaceState(nextState);
        return;
      case RealtimeSocketEventType.collaborationAborted:
        final payload = event.payload;
        if (payload == null) {
          return;
        }
        final nextState = _appendCollaborationRun(
          _mergeCollaborationStatus(
            current,
            payload,
            fallbackStatus: 'ABORTED',
          ),
          payload,
          fallbackStatus: 'ABORTED',
        );
        _setWorkspaceState(nextState);
        return;
      case RealtimeSocketEventType.subscribed:
      case RealtimeSocketEventType.error:
      case RealtimeSocketEventType.unknown:
        return;
    }
  }
}
