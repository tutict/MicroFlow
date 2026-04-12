import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../app/router.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../../../core/providers/locale_controller.dart';
import '../../../../core/providers/theme_mode_controller.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/language_switcher.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/theme_mode_switcher.dart';
import '../../../agents/domain/entities/agent_descriptor.dart';
import '../../../agents/presentation/widgets/agent_panel.dart';
import '../../../auth/presentation/providers/auth_session_controller.dart';
import '../../../chat/domain/entities/chat_message.dart';
import '../../domain/entities/workspace_conversation.dart';
import '../../../chat/presentation/state/chat_connection_status.dart';
import '../../../chat/presentation/widgets/chat_panel.dart';
import '../providers/workspace_shell_controller.dart';
import '../state/workspace_shell_state.dart';
import '../state/workspace_selected_conversation.dart';
import '../widgets/workspace_panel.dart';

class WorkspaceHomePage extends ConsumerStatefulWidget {
  const WorkspaceHomePage({super.key});

  @override
  ConsumerState<WorkspaceHomePage> createState() => _WorkspaceHomePageState();
}

class _WorkspaceHomePageState extends ConsumerState<WorkspaceHomePage> {
  int _mobileTabIndex = 0;

  Future<void> _signOut() async {
    await ref
        .read(workspaceShellControllerProvider.notifier)
        .disconnectRealtime();
    await ref.read(authSessionControllerProvider.notifier).signOut();
    ref.invalidate(workspaceShellControllerProvider);
    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.signIn, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shellAsync = ref.watch(workspaceShellControllerProvider);
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 1100;
    final isCompactMobile = !isWide && width < 640;
    final isMobileChatTab = !isWide && _mobileTabIndex == 0;
    final bodyPadding = EdgeInsets.fromLTRB(
      isMobileChatTab ? 8 : (isCompactMobile ? 14 : 18),
      isMobileChatTab ? 6 : (isCompactMobile ? 10 : 14),
      isMobileChatTab ? 8 : (isCompactMobile ? 14 : 18),
      isMobileChatTab ? 6 : (isCompactMobile ? 12 : 16),
    );
    final appBarStatus = StatusBadge(
      label: _connectionLabel(l10n, shellAsync.valueOrNull?.connectionStatus),
      color: _connectionColor(shellAsync.valueOrNull?.connectionStatus),
    );
    final mobileStatusColor = _connectionColor(
      shellAsync.valueOrNull?.connectionStatus,
    );
    final mobileStatusLabel = _connectionLabel(
      l10n,
      shellAsync.valueOrNull?.connectionStatus,
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isCompactMobile ? 64 : 72,
        titleSpacing: isCompactMobile ? 12 : 16,
        title: Row(
          children: [
            Container(
              width: isCompactMobile ? 34 : 38,
              height: isCompactMobile ? 34 : 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                'MF',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            SizedBox(width: isCompactMobile ? 10 : 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    isWide ? l10n.workspaceHub : mobileStatusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isWide
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.62)
                          : mobileStatusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: Localizations.localeOf(context).languageCode == 'zh'
                ? 'Agent 诊断'
                : 'Agent diagnostics',
            onPressed: shellAsync.valueOrNull?.workspaceId.isEmpty ?? true
                ? null
                : () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.agents,
                      arguments: shellAsync.valueOrNull!.workspaceId,
                    );
                  },
            icon: const Icon(Icons.health_and_safety_rounded),
          ),
          if (isWide) ...[
            const ThemeModeSwitcher(),
            const SizedBox(width: 8),
            const LanguageSwitcher(),
            const SizedBox(width: 8),
          ],
          if (isWide)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: appBarStatus),
            ),
          IconButton(
            tooltip: l10n.signOutTooltip,
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          if (!isWide) ...[
            const SizedBox(width: 4),
            PopupMenuButton<int>(
              tooltip: l10n.language,
              onSelected: (value) {
                switch (value) {
                  case 1:
                    ref
                        .read(themeModeControllerProvider.notifier)
                        .setThemeMode(ThemeMode.light);
                    break;
                  case 2:
                    ref
                        .read(themeModeControllerProvider.notifier)
                        .setThemeMode(ThemeMode.dark);
                    break;
                  case 3:
                    ref
                        .read(localeControllerProvider.notifier)
                        .setLocale(const Locale('zh'));
                    break;
                  case 4:
                    ref
                        .read(localeControllerProvider.notifier)
                        .setLocale(const Locale('en'));
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 1, child: Text(l10n.lightMode)),
                PopupMenuItem(value: 2, child: Text(l10n.darkMode)),
                PopupMenuItem(value: 3, child: Text(l10n.simplifiedChinese)),
                PopupMenuItem(value: 4, child: Text(l10n.english)),
              ],
              icon: const Icon(Icons.tune_rounded),
            ),
            const SizedBox(width: 12),
          ] else
            const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.brightness == Brightness.dark
                ? const [
                    Color(0xFF081015),
                    Color(0xFF10191F),
                    Color(0xFF152229),
                  ]
                : const [
                    Color(0xFFF7F9F9),
                    Color(0xFFEEF2F3),
                    Color(0xFFE3EAEC),
                  ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: bodyPadding,
            child: shellAsync.when(
              data: (shell) {
                final conversations = _mapConversationSummaries(
                  shell.conversations,
                );
                final members = _buildWorkspaceMembers(
                  l10n: l10n,
                  currentUserId: shell.currentUserId,
                  currentUserLabel: shell.currentUserLabel,
                  conversations: shell.conversations,
                );
                final recentInteractions = _buildRecentInteractions(
                  l10n: l10n,
                  currentUserId: shell.currentUserId,
                  currentUserLabel: shell.currentUserLabel,
                  messages: shell.messages,
                );
                final unreadTotal = conversations.fold<int>(
                  0,
                  (sum, conversation) => sum + conversation.unreadCount,
                );
                final enabledAgents = shell.agents
                    .where((agent) => agent.enabled)
                    .length;
                final isWorkspaceBootstrap =
                    shell.workspaceId.isEmpty && conversations.isEmpty;
                final needsConversationSetup =
                    !isWorkspaceBootstrap && conversations.isEmpty;
                final desktopSidebarWidth = width >= 1440 ? 320.0 : 300.0;
                final desktopAgentWidth = width >= 1440 ? 300.0 : 272.0;

                final chatPanel = ChatPanel(
                  channelName: shell.selectedConversation.title,
                  conversationLabel: _conversationLabel(
                    l10n,
                    shell.selectedConversation,
                  ),
                  conversationDescription: _conversationDescription(
                    l10n,
                    shell.selectedConversation,
                  ),
                  statusLabel: _conversationStatusLabel(
                    l10n,
                    shell.selectedConversation,
                  ),
                  statusColor: _conversationStatusColor(
                    shell.selectedConversation,
                  ),
                  canSendMessage: _canSendMessage(shell.selectedConversation),
                  composerHintText: _composerHintText(
                    l10n,
                    shell.selectedConversation,
                  ),
                  emptyStateTitle: _emptyConversationTitle(
                    l10n,
                    shell.selectedConversation,
                  ),
                  emptyStateDescription: _emptyConversationDescription(
                    l10n,
                    shell.selectedConversation,
                  ),
                  emptyStateIcon: _emptyConversationIcon(
                    shell.selectedConversation,
                  ),
                  messages: shell.messages,
                  currentUserId: shell.currentUserId,
                  currentUserLabel: shell.currentUserLabel,
                  participants: _buildConversationParticipants(
                    l10n: l10n,
                    currentUserId: shell.currentUserId,
                    currentUserLabel: shell.currentUserLabel,
                    selectedConversation: shell.selectedConversation,
                    messages: shell.messages,
                  ),
                  activeParticipantCount: _conversationParticipantCount(
                    l10n: l10n,
                    currentUserId: shell.currentUserId,
                    currentUserLabel: shell.currentUserLabel,
                    selectedConversation: shell.selectedConversation,
                    messages: shell.messages,
                  ),
                  suggestedMentions: _buildSuggestedMentions(
                    shell.agents,
                    shell.selectedConversation,
                  ),
                  collaborationModeAvailable: _supportsCollaboration(
                    shell.selectedConversation,
                    shell.agents,
                  ),
                  collaborationModeEnabled:
                      shell.isCollaborationEnabledForSelectedConversation,
                  collaborationStatusText: _collaborationStatusText(
                    l10n,
                    shell.selectedCollaborationStatus,
                  ),
                  onCollaborationModeChanged: (enabled) {
                    ref
                        .read(workspaceShellControllerProvider.notifier)
                        .setCollaborationModeForSelectedConversation(enabled);
                  },
                  compact: isCompactMobile,
                  isSendingMessage: shell.isSendingMessage,
                  messageError: shell.messageError,
                  onSend: (value) {
                    return ref
                        .read(workspaceShellControllerProvider.notifier)
                        .sendMessage(value);
                  },
                );

                if (isWorkspaceBootstrap) {
                  return _WorkspaceSetupPanel(
                    compact: !isWide,
                    title: shell.workspaceName,
                    eyebrow: l10n.workspaceHub,
                    description: l10n.workspaceDescription,
                    primaryStatValue: '${conversations.length}',
                    primaryStatLabel: l10n.conversations,
                    secondaryStatValue: '$enabledAgents',
                    secondaryStatLabel: l10n.availableAgents,
                    note: l10n.privateConversationPreview,
                    primaryActionLabel: !isWide ? l10n.agents : null,
                    onPrimaryAction: !isWide
                        ? () {
                            setState(() {
                              _mobileTabIndex = 2;
                            });
                          }
                        : null,
                    primaryActionIcon: Icons.smart_toy_rounded,
                    secondaryActionLabel: l10n.signOutTooltip,
                    onSecondaryAction: _signOut,
                    secondaryActionIcon: Icons.logout_rounded,
                  );
                }

                final setupPanel = _WorkspaceSetupPanel(
                  compact: !isWide,
                  title: l10n.noMessagesTitle,
                  eyebrow: shell.workspaceName,
                  description: l10n.noMessagesDescription,
                  primaryStatValue: '${conversations.length}',
                  primaryStatLabel: l10n.conversations,
                  secondaryStatValue: '$enabledAgents',
                  secondaryStatLabel: l10n.availableAgents,
                  note: l10n.agentConversationHint,
                  primaryActionLabel: !isWide ? l10n.collaboration : null,
                  onPrimaryAction: !isWide
                      ? () {
                          setState(() {
                            _mobileTabIndex = 1;
                          });
                        }
                      : null,
                  primaryActionIcon: Icons.grid_view_rounded,
                  secondaryActionLabel: !isWide ? l10n.agents : null,
                  onSecondaryAction: !isWide
                      ? () {
                          setState(() {
                            _mobileTabIndex = 2;
                          });
                        }
                      : null,
                  secondaryActionIcon: Icons.smart_toy_rounded,
                );

                return isWide
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DesktopWorkspaceLead(
                            workspaceName: shell.workspaceName,
                            selectedConversationTitle:
                                shell.selectedConversation.title,
                            selectedConversationLabel: _conversationLabel(
                              l10n,
                              shell.selectedConversation,
                            ),
                            statusLabel: _conversationStatusLabel(
                              l10n,
                              shell.selectedConversation,
                            ),
                            statusColor: _conversationStatusColor(
                              shell.selectedConversation,
                            ),
                            conversationCount: conversations.length,
                            unreadCount: unreadTotal,
                            agentCount: enabledAgents,
                            conversationsLabel: l10n.conversations,
                            unreadLabel: l10n.unreadLabel,
                            agentsLabel: l10n.availableAgents,
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: desktopSidebarWidth,
                                  child: _ScrollablePanel(
                                    child: WorkspacePanel(
                                      workspaceName: shell.workspaceName,
                                      description: l10n.workspaceDescription,
                                      channels: _filterConversationSummaries(
                                        shell.conversations,
                                        WorkspaceConversationKind.channel,
                                      ),
                                      conversations: conversations,
                                      members: members,
                                      recentInteractions: recentInteractions,
                                      selectedConversationId:
                                          shell.selectedConversationId,
                                      compact: false,
                                      onOpenConversation: (conversation) {
                                        _openConversation(
                                          ref: ref,
                                          conversation: conversation,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: needsConversationSetup
                                      ? setupPanel
                                      : chatPanel,
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: desktopAgentWidth,
                                  child: _ScrollablePanel(
                                    child: AgentPanel(
                                      agents: shell.agents,
                                      runs: shell.agentRuns,
                                      compact: false,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: IndexedStack(
                              index: _mobileTabIndex,
                              children: [
                                needsConversationSetup ? setupPanel : chatPanel,
                                ListView(
                                  padding: const EdgeInsets.only(
                                    top: 2,
                                    bottom: 4,
                                  ),
                                  children: [
                                    WorkspacePanel(
                                      workspaceName: shell.workspaceName,
                                      description: l10n.workspaceDescription,
                                      channels: _filterConversationSummaries(
                                        shell.conversations,
                                        WorkspaceConversationKind.channel,
                                      ),
                                      conversations: conversations,
                                      members: members,
                                      recentInteractions: recentInteractions,
                                      selectedConversationId:
                                          shell.selectedConversationId,
                                      compact: true,
                                      onOpenConversation: (conversation) {
                                        _openConversation(
                                          ref: ref,
                                          conversation: conversation,
                                          onChannelOpened: () {
                                            setState(() {
                                              _mobileTabIndex = 0;
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                ListView(
                                  padding: const EdgeInsets.only(
                                    top: 2,
                                    bottom: 4,
                                  ),
                                  children: [
                                    AgentPanel(
                                      agents: shell.agents,
                                      runs: shell.agentRuns,
                                      compact: true,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(l10n.workspaceLoadError(error.toString())),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: !isWide
          ? _MobileBottomNav(
              currentIndex: _mobileTabIndex,
              onSelected: (index) {
                setState(() {
                  _mobileTabIndex = index;
                });
              },
              items: [
                _MobileNavItemData(
                  icon: Icons.chat_bubble_rounded,
                  label: l10n.chatTab,
                ),
                _MobileNavItemData(
                  icon: Icons.grid_view_rounded,
                  label: l10n.collaboration,
                ),
                _MobileNavItemData(
                  icon: Icons.smart_toy_rounded,
                  label: l10n.agents,
                ),
              ],
            )
          : null,
    );
  }
}

Future<void> _openConversation({
  required WidgetRef ref,
  required WorkspaceConversationSummary conversation,
  VoidCallback? onChannelOpened,
}) async {
  await ref
      .read(workspaceShellControllerProvider.notifier)
      .selectConversation(
        conversationId: conversation.id,
        title: conversation.title,
        kind: _toSelectedConversationKind(conversation.kind),
        isAvailable: conversation.isAvailable,
      );
  if (conversation.kind == WorkspaceConversationKind.channel) {
    onChannelOpened?.call();
  }
}

List<WorkspaceConversationSummary> _mapConversationSummaries(
  List<WorkspaceConversation> conversations,
) {
  return conversations
      .map(
        (conversation) => WorkspaceConversationSummary(
          id: conversation.id,
          title: conversation.title,
          subtitle: conversation.subtitle,
          kind: _mapConversationKind(conversation.kind),
          accent: _accentForConversation(
            kind: _mapConversationKind(conversation.kind),
            available: conversation.available,
          ),
          lastActivityAt: conversation.lastActivityAt,
          unreadCount: conversation.unreadCount,
          isAvailable: conversation.available,
        ),
      )
      .toList(growable: false);
}

List<WorkspaceConversationSummary> _filterConversationSummaries(
  List<WorkspaceConversation> conversations,
  WorkspaceConversationKind kind,
) {
  return _mapConversationSummaries(
    conversations,
  ).where((conversation) => conversation.kind == kind).toList(growable: false);
}

WorkspaceConversationKind _mapConversationKind(String kind) {
  return switch (kind) {
    'CHANNEL' => WorkspaceConversationKind.channel,
    'DIRECT_MESSAGE' => WorkspaceConversationKind.directMessage,
    'AGENT_DM' => WorkspaceConversationKind.agentThread,
    _ => WorkspaceConversationKind.channel,
  };
}

WorkspaceSelectedConversationKind _toSelectedConversationKind(
  WorkspaceConversationKind kind,
) {
  return switch (kind) {
    WorkspaceConversationKind.channel =>
      WorkspaceSelectedConversationKind.channel,
    WorkspaceConversationKind.directMessage =>
      WorkspaceSelectedConversationKind.directMessage,
    WorkspaceConversationKind.agentThread =>
      WorkspaceSelectedConversationKind.agentThread,
  };
}

Color _accentForConversation({
  required WorkspaceConversationKind kind,
  required bool available,
}) {
  return switch (kind) {
    WorkspaceConversationKind.channel => const Color(0xFF3D7EA6),
    WorkspaceConversationKind.directMessage => const Color(0xFF52796F),
    WorkspaceConversationKind.agentThread =>
      available ? const Color(0xFF1F8A5C) : const Color(0xFF7A8791),
  };
}

List<WorkspaceMemberSummary> _buildWorkspaceMembers({
  required AppLocalizations l10n,
  required String currentUserId,
  required String currentUserLabel,
  required List<WorkspaceConversation> conversations,
}) {
  final members = <WorkspaceMemberSummary>[
    WorkspaceMemberSummary(
      id: currentUserId,
      displayName: currentUserLabel,
      subtitle: l10n.online,
      accent: const Color(0xFF3D7EA6),
      isCurrentUser: true,
    ),
  ];
  final seen = <String>{currentUserId};

  for (final conversation in conversations) {
    if (_mapConversationKind(conversation.kind) !=
            WorkspaceConversationKind.directMessage ||
        !seen.add(conversation.id)) {
      continue;
    }
    members.add(
      WorkspaceMemberSummary(
        id: conversation.id,
        displayName: conversation.title,
        subtitle: l10n.online,
        accent: const Color(0xFF52796F),
        isCurrentUser: false,
      ),
    );
  }

  return members;
}

List<WorkspaceRecentInteractionSummary> _buildRecentInteractions({
  required AppLocalizations l10n,
  required String currentUserId,
  required String currentUserLabel,
  required List<ChatMessage> messages,
}) {
  final latestMessages = messages.reversed.take(5);

  return latestMessages
      .map((message) {
        final parsed = DateTime.tryParse(message.createdAt)?.toLocal();
        final preview = message.text.trim().replaceAll(RegExp(r'\s+'), ' ');

        return WorkspaceRecentInteractionSummary(
          authorLabel: _memberOrAgentLabel(
            l10n: l10n,
            currentUserId: currentUserId,
            currentUserLabel: currentUserLabel,
            author: message.author,
            isAgent: message.isAgent,
          ),
          preview: preview,
          timestampLabel: parsed == null
              ? message.createdAt
              : formatShortTimestamp(parsed),
          accent: message.isAgent
              ? const Color(0xFF1F8A5C)
              : const Color(0xFF52796F),
          isAgent: message.isAgent,
        );
      })
      .toList(growable: false);
}

String _memberDisplayLabel(AppLocalizations l10n, String authorId) {
  final compact = authorId.length > 12
      ? '${authorId.substring(0, 12)}...'
      : authorId;
  return l10n.memberLabel(compact);
}

String _memberOrAgentLabel({
  required AppLocalizations l10n,
  required String currentUserId,
  required String currentUserLabel,
  required String author,
  required bool isAgent,
}) {
  if (author == currentUserId) {
    return currentUserLabel;
  }
  if (isAgent && author.startsWith('agent:')) {
    return '@${author.substring('agent:'.length)}';
  }
  return _memberDisplayLabel(l10n, author);
}

List<ChatParticipantPreview> _buildConversationParticipants({
  required AppLocalizations l10n,
  required String currentUserId,
  required String currentUserLabel,
  required WorkspaceSelectedConversation selectedConversation,
  required List<ChatMessage> messages,
}) {
  if (selectedConversation.kind ==
      WorkspaceSelectedConversationKind.directMessage) {
    return [
      ChatParticipantPreview(
        label: currentUserLabel,
        accent: const Color(0xFF3D7EA6),
      ),
      ChatParticipantPreview(
        label: selectedConversation.title,
        accent: const Color(0xFF52796F),
      ),
    ];
  }

  if (selectedConversation.kind ==
      WorkspaceSelectedConversationKind.agentThread) {
    return [
      ChatParticipantPreview(
        label: currentUserLabel,
        accent: const Color(0xFF3D7EA6),
      ),
      ChatParticipantPreview(
        label: selectedConversation.title,
        accent: const Color(0xFF1F8A5C),
      ),
    ];
  }

  final participants = <ChatParticipantPreview>[
    ChatParticipantPreview(
      label: currentUserLabel,
      accent: const Color(0xFF3D7EA6),
    ),
  ];
  final seen = <String>{currentUserId};
  final seenAgents = <String>{};

  for (final message in messages) {
    if (message.isAgent) {
      if (!seenAgents.add(message.author)) {
        continue;
      }
      participants.add(
        ChatParticipantPreview(
          label: _memberOrAgentLabel(
            l10n: l10n,
            currentUserId: currentUserId,
            currentUserLabel: currentUserLabel,
            author: message.author,
            isAgent: true,
          ),
          accent: const Color(0xFF1F8A5C),
        ),
      );
      continue;
    }
    if (!seen.add(message.author)) {
      continue;
    }
    participants.add(
      ChatParticipantPreview(
        label: _memberDisplayLabel(l10n, message.author),
        accent: const Color(0xFF52796F),
      ),
    );
  }

  return participants;
}

int _conversationParticipantCount({
  required AppLocalizations l10n,
  required String currentUserId,
  required String currentUserLabel,
  required WorkspaceSelectedConversation selectedConversation,
  required List<ChatMessage> messages,
}) {
  return _buildConversationParticipants(
    l10n: l10n,
    currentUserId: currentUserId,
    currentUserLabel: currentUserLabel,
    selectedConversation: selectedConversation,
    messages: messages,
  ).length;
}

List<String> _buildSuggestedMentions(
  List<AgentDescriptor> agents,
  WorkspaceSelectedConversation selectedConversation,
) {
  if (selectedConversation.kind ==
      WorkspaceSelectedConversationKind.agentThread) {
    return const [];
  }
  final mentions = <String>[
    if (selectedConversation.kind == WorkspaceSelectedConversationKind.channel)
      '@team',
    if (selectedConversation.kind == WorkspaceSelectedConversationKind.channel)
      '@all-agents',
  ];
  mentions.addAll(
    agents
        .where((agent) => agent.enabled)
        .map((agent) => '@${agent.agentKey}')
        .toList(growable: false),
  );
  return mentions;
}

bool _supportsCollaboration(
  WorkspaceSelectedConversation selectedConversation,
  List<AgentDescriptor> agents,
) {
  return selectedConversation.kind ==
          WorkspaceSelectedConversationKind.channel &&
      agents.any((agent) => agent.enabled);
}

String? _collaborationStatusText(
  AppLocalizations l10n,
  CollaborationStatusSnapshot? status,
) {
  if (status == null) {
    return null;
  }
  final roundLabel = status.maxRounds > 0
      ? l10n.collaborationRoundStatus(status.round, status.maxRounds)
      : '';
  return switch (status.status) {
    'RUNNING' => l10n.collaborationRunningStatus(
      status.activeAgentKey == null || status.activeAgentKey!.isEmpty
          ? '@team'
          : '@${status.activeAgentKey}',
      roundLabel,
    ),
    'COMPLETED' => l10n.collaborationCompletedStatus(
      status.trigger,
      status.maxRounds,
    ),
    'ABORTED' => l10n.collaborationStoppedStatus,
    _ => l10n.collaborationModeHint,
  };
}

bool _canSendMessage(WorkspaceSelectedConversation selectedConversation) {
  return selectedConversation.isAvailable;
}

String _conversationLabel(
  AppLocalizations l10n,
  WorkspaceSelectedConversation selectedConversation,
) {
  return switch (selectedConversation.kind) {
    WorkspaceSelectedConversationKind.channel =>
      '# ${selectedConversation.title}',
    WorkspaceSelectedConversationKind.directMessage =>
      selectedConversation.title,
    WorkspaceSelectedConversationKind.agentThread => l10n.agentThreads,
  };
}

String _conversationDescription(
  AppLocalizations l10n,
  WorkspaceSelectedConversation selectedConversation,
) {
  return switch (selectedConversation.kind) {
    WorkspaceSelectedConversationKind.channel => l10n.chatPanelDescription,
    WorkspaceSelectedConversationKind.directMessage =>
      selectedConversation.isAvailable
          ? l10n.memberConversationHint
          : l10n.privateConversationPreview,
    WorkspaceSelectedConversationKind.agentThread =>
      selectedConversation.isAvailable
          ? l10n.agentConversationHint
          : l10n.privateConversationPreview,
  };
}

String _conversationStatusLabel(
  AppLocalizations l10n,
  WorkspaceSelectedConversation selectedConversation,
) {
  if (!selectedConversation.isAvailable) {
    return l10n.previewLabel;
  }
  return switch (selectedConversation.kind) {
    WorkspaceSelectedConversationKind.channel => l10n.aiEnabled,
    WorkspaceSelectedConversationKind.directMessage => l10n.connected,
    WorkspaceSelectedConversationKind.agentThread => l10n.aiEnabled,
  };
}

Color _conversationStatusColor(
  WorkspaceSelectedConversation selectedConversation,
) {
  if (!selectedConversation.isAvailable) {
    return const Color(0xFF7A8791);
  }
  return switch (selectedConversation.kind) {
    WorkspaceSelectedConversationKind.channel => const Color(0xFF1F6F5C),
    WorkspaceSelectedConversationKind.directMessage => const Color(0xFF52796F),
    WorkspaceSelectedConversationKind.agentThread => const Color(0xFF1F8A5C),
  };
}

String _composerHintText(
  AppLocalizations l10n,
  WorkspaceSelectedConversation selectedConversation,
) {
  if (selectedConversation.kind ==
      WorkspaceSelectedConversationKind.directMessage) {
    return l10n.memberConversationHint;
  }
  if (selectedConversation.kind ==
      WorkspaceSelectedConversationKind.agentThread) {
    return l10n.agentConversationHint;
  }
  return l10n.typeMessageHint;
}

String _emptyConversationTitle(
  AppLocalizations l10n,
  WorkspaceSelectedConversation selectedConversation,
) {
  return switch (selectedConversation.kind) {
    WorkspaceSelectedConversationKind.channel => l10n.noMessagesTitle,
    WorkspaceSelectedConversationKind.directMessage =>
      selectedConversation.title,
    WorkspaceSelectedConversationKind.agentThread => selectedConversation.title,
  };
}

String _emptyConversationDescription(
  AppLocalizations l10n,
  WorkspaceSelectedConversation selectedConversation,
) {
  return switch (selectedConversation.kind) {
    WorkspaceSelectedConversationKind.channel => l10n.noMessagesDescription,
    WorkspaceSelectedConversationKind.directMessage =>
      selectedConversation.isAvailable
          ? l10n.memberConversationHint
          : l10n.privateConversationPreview,
    WorkspaceSelectedConversationKind.agentThread =>
      selectedConversation.isAvailable
          ? l10n.agentConversationHint
          : l10n.privateConversationPreview,
  };
}

IconData _emptyConversationIcon(
  WorkspaceSelectedConversation selectedConversation,
) {
  return switch (selectedConversation.kind) {
    WorkspaceSelectedConversationKind.channel => Icons.forum_rounded,
    WorkspaceSelectedConversationKind.directMessage => Icons.person_rounded,
    WorkspaceSelectedConversationKind.agentThread => Icons.smart_toy_rounded,
  };
}

class _ScrollablePanel extends StatelessWidget {
  const _ScrollablePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.only(bottom: 4), child: child),
    );
  }
}

class _DesktopWorkspaceLead extends StatelessWidget {
  const _DesktopWorkspaceLead({
    required this.workspaceName,
    required this.selectedConversationTitle,
    required this.selectedConversationLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.conversationCount,
    required this.unreadCount,
    required this.agentCount,
    required this.conversationsLabel,
    required this.unreadLabel,
    required this.agentsLabel,
  });

  final String workspaceName;
  final String selectedConversationTitle;
  final String selectedConversationLabel;
  final String statusLabel;
  final Color statusColor;
  final int conversationCount;
  final int unreadCount;
  final int agentCount;
  final String conversationsLabel;
  final String unreadLabel;
  final String agentsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.46 : 0.72,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.82)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workspaceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedConversationTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppPill(
                      label: selectedConversationLabel,
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: theme.brightness == Brightness.dark ? 0.18 : 0.1,
                      ),
                      borderColor: theme.colorScheme.primary.withValues(
                        alpha: 0.16,
                      ),
                      labelColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    StatusBadge(label: statusLabel, color: statusColor),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DesktopMetricPill(
                value: '$conversationCount',
                label: conversationsLabel,
              ),
              _DesktopMetricPill(value: '$unreadCount', label: unreadLabel),
              _DesktopMetricPill(value: '$agentCount', label: agentsLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesktopMetricPill extends StatelessWidget {
  const _DesktopMetricPill({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 108,
      child: AppPill(
        value: value,
        label: label,
        backgroundColor: theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.38 : 0.88,
        ),
        borderColor: theme.dividerColor.withValues(alpha: 0.82),
        valueColor: theme.colorScheme.onSurface,
        labelColor: theme.colorScheme.onSurface.withValues(alpha: 0.62),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _WorkspaceSetupPanel extends StatelessWidget {
  const _WorkspaceSetupPanel({
    required this.compact,
    required this.title,
    required this.eyebrow,
    required this.description,
    required this.primaryStatValue,
    required this.primaryStatLabel,
    required this.secondaryStatValue,
    required this.secondaryStatLabel,
    required this.note,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.primaryActionIcon = Icons.arrow_forward_rounded,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.secondaryActionIcon = Icons.logout_rounded,
  });

  final bool compact;
  final String title;
  final String eyebrow;
  final String description;
  final String primaryStatValue;
  final String primaryStatLabel;
  final String secondaryStatValue;
  final String secondaryStatLabel;
  final String note;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final IconData primaryActionIcon;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final IconData secondaryActionIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.brightness == Brightness.dark
              ? const [Color(0xFF162229), Color(0xFF111C22)]
              : const [Color(0xFFFCFDFD), Color(0xFFF2F6F7)],
        ),
        borderRadius: BorderRadius.circular(compact ? 22 : 30),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? const Color(0xFF23323A)
              : const Color(0xFFD9E3E7),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark
                ? const Color(0x30000000)
                : const Color(0x160E1A22),
            blurRadius: compact ? 18 : 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 18 : 32,
          compact ? 20 : 34,
          compact ? 18 : 32,
          compact ? 18 : 28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.18 : 0.1,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                eyebrow,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(height: compact ? 16 : 20),
            Text(
              title,
              style:
                  (compact
                          ? theme.textTheme.headlineSmall
                          : theme.textTheme.headlineLarge)
                      ?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: compact ? -0.4 : -0.8,
                      ),
            ),
            SizedBox(height: compact ? 10 : 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 520 : 640),
              child: Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  height: 1.5,
                ),
              ),
            ),
            SizedBox(height: compact ? 18 : 22),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DesktopMetricPill(
                  value: primaryStatValue,
                  label: primaryStatLabel,
                ),
                _DesktopMetricPill(
                  value: secondaryStatValue,
                  label: secondaryStatLabel,
                ),
              ],
            ),
            SizedBox(height: compact ? 16 : 20),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(compact ? 16 : 18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.34 : 0.72,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.82),
                ),
              ),
              child: Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ),
            const Spacer(),
            if (primaryActionLabel != null || secondaryActionLabel != null)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (primaryActionLabel != null)
                    FilledButton.icon(
                      onPressed: onPrimaryAction,
                      icon: Icon(primaryActionIcon, size: 18),
                      label: Text(primaryActionLabel!),
                    ),
                  if (secondaryActionLabel != null)
                    OutlinedButton.icon(
                      onPressed: onSecondaryAction,
                      icon: Icon(secondaryActionIcon, size: 18),
                      label: Text(secondaryActionLabel!),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MobileNavItemData {
  const _MobileNavItemData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav({
    required this.currentIndex,
    required this.onSelected,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final List<_MobileNavItemData> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.dividerColor),
            boxShadow: [
              BoxShadow(
                color: theme.brightness == Brightness.dark
                    ? const Color(0x24000000)
                    : const Color(0x120E1A22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: _MobileNavItem(
                    data: items[index],
                    selected: index == currentIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _MobileNavItemData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.22 : 0.14,
                  )
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                data.icon,
                size: 20,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.68),
              ),
              const SizedBox(height: 4),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _connectionLabel(AppLocalizations l10n, ChatConnectionStatus? status) {
  return switch (status) {
    ChatConnectionStatus.connected => l10n.connected,
    ChatConnectionStatus.connecting => l10n.connecting,
    ChatConnectionStatus.disconnected => l10n.disconnected,
    ChatConnectionStatus.error => l10n.realtimeError,
    _ => l10n.idle,
  };
}

Color _connectionColor(ChatConnectionStatus? status) {
  return switch (status) {
    ChatConnectionStatus.connected => const Color(0xFF1F8A5C),
    ChatConnectionStatus.connecting => const Color(0xFF3D7EA6),
    ChatConnectionStatus.error => const Color(0xFFBA3B2F),
    _ => const Color(0xFF6C7A89),
  };
}
