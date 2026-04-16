import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
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
import '../../../agents/domain/entities/agent_run.dart';
import '../../../agents/presentation/widgets/agent_panel.dart';
import '../../../auth/presentation/providers/auth_session_controller.dart';
import '../../../chat/domain/entities/chat_message.dart';
import '../../domain/entities/knowledge_document.dart';
import '../../domain/entities/workspace_member.dart';
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

  Future<void> _openAgentSheet({
    required List<AgentDescriptor> agents,
    required List<AgentRun> runs,
  }) async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.agents,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          sheetContext,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: theme.dividerColor),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: AgentPanel(
                      agents: agents,
                      runs: runs,
                      compact: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _promptCreateWorkspace() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final createdName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.newWorkspaceTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.workspaceNameLabel,
              hintText: l10n.workspaceNameHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
              ),
              child: Text(l10n.create),
            ),
          ],
        );
      },
    );
    if (!mounted || createdName == null || createdName.trim().isEmpty) {
      return;
    }
    try {
      await ref
          .read(workspaceShellControllerProvider.notifier)
          .createWorkspace(createdName);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openKnowledgeSheet(
    WorkspaceShellState shell, {
    String? initialDocumentId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final latestShell =
                ref.watch(workspaceShellControllerProvider).valueOrNull ??
                shell;
            final theme = Theme.of(sheetContext);
            return FractionallySizedBox(
              heightFactor: 0.92,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: _KnowledgeSheet(
                  shell: latestShell,
                  initialDocumentId: initialDocumentId,
                  onRefresh: () {
                    return ref
                        .read(workspaceShellControllerProvider.notifier)
                        .refreshKnowledgeDocuments();
                  },
                  onUpload: (targetChannelId) async {
                    final result = await FilePicker.platform.pickFiles(
                      withData: true,
                    );
                    if (result == null ||
                        result.files.isEmpty ||
                        result.files.first.bytes == null) {
                      return;
                    }
                    await ref
                        .read(workspaceShellControllerProvider.notifier)
                        .uploadKnowledgeDocument(
                          fileName: result.files.first.name,
                          bytes: result.files.first.bytes!,
                          channelId: targetChannelId,
                          inheritSelectedConversation:
                              targetChannelId != null &&
                              targetChannelId.isNotEmpty,
                        );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _promptAddMember() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.addWorkspaceMemberTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: l10n.userEmailLabel,
              hintText: l10n.userEmailHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(l10n.add),
            ),
          ],
        );
      },
    );
    if (!mounted || email == null || email.trim().isEmpty) {
      return;
    }
    try {
      await ref
          .read(workspaceShellControllerProvider.notifier)
          .addMemberByEmail(email);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _handlePhoneMenuSelection(
    _PhoneMenuAction action,
    WorkspaceShellState? shell,
    bool canManageMembers,
  ) async {
    switch (action) {
      case _PhoneMenuAction.newWorkspace:
        await _promptCreateWorkspace();
        return;
      case _PhoneMenuAction.knowledge:
        if (shell != null && shell.workspaceId.isNotEmpty) {
          await _openKnowledgeSheet(shell);
        }
        return;
      case _PhoneMenuAction.addMember:
        if (canManageMembers) {
          await _promptAddMember();
        }
        return;
      case _PhoneMenuAction.diagnostics:
        if (!mounted || shell == null || shell.workspaceId.isEmpty) {
          return;
        }
        Navigator.of(
          context,
        ).pushNamed(AppRoutes.agents, arguments: shell.workspaceId);
        return;
      case _PhoneMenuAction.lightMode:
        ref
            .read(themeModeControllerProvider.notifier)
            .setThemeMode(ThemeMode.light);
        return;
      case _PhoneMenuAction.darkMode:
        ref
            .read(themeModeControllerProvider.notifier)
            .setThemeMode(ThemeMode.dark);
        return;
      case _PhoneMenuAction.chinese:
        ref
            .read(localeControllerProvider.notifier)
            .setLocale(const Locale('zh'));
        return;
      case _PhoneMenuAction.english:
        ref
            .read(localeControllerProvider.notifier)
            .setLocale(const Locale('en'));
        return;
      case _PhoneMenuAction.signOut:
        await _signOut();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shellAsync = ref.watch(workspaceShellControllerProvider);
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isDesktop = width >= 1280;
    final isTablet = width >= 820 && !isDesktop;
    final isPhone = !isDesktop && !isTablet;
    final isCompactPhone = isPhone && width < 640;
    final isPhoneChatTab = isPhone && _mobileTabIndex == 0;
    final bodyPadding = EdgeInsets.fromLTRB(
      isPhoneChatTab ? 8 : (isCompactPhone ? 14 : 18),
      isPhoneChatTab ? 6 : (isCompactPhone ? 10 : 14),
      isPhoneChatTab ? 8 : (isCompactPhone ? 14 : 18),
      isPhoneChatTab ? 6 : (isCompactPhone ? 12 : 16),
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
    final canManageMembers =
        shellAsync.valueOrNull?.workspaceMembers.any(
          (member) =>
              member.userId == shellAsync.valueOrNull?.currentUserId &&
              member.role == 'OWNER',
        ) ??
        false;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isCompactPhone ? 64 : 72,
        titleSpacing: isCompactPhone ? 12 : 16,
        title: Row(
          children: [
            Container(
              width: isCompactPhone ? 34 : 38,
              height: isCompactPhone ? 34 : 38,
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
            SizedBox(width: isCompactPhone ? 10 : 12),
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
                    isDesktop || isTablet
                        ? l10n.workspaceHub
                        : mobileStatusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDesktop || isTablet
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
          if ((shellAsync.valueOrNull?.workspaces.length ?? 0) > 1)
            PopupMenuButton<String>(
              tooltip: l10n.switchWorkspaceTooltip,
              onSelected: (workspaceId) {
                ref
                    .read(workspaceShellControllerProvider.notifier)
                    .selectWorkspace(workspaceId);
              },
              itemBuilder: (context) {
                final shell = shellAsync.valueOrNull!;
                return shell.workspaces
                    .map(
                      (workspace) => PopupMenuItem<String>(
                        value: workspace.id,
                        child: Row(
                          children: [
                            Icon(
                              workspace.id == shell.workspaceId
                                  ? Icons.check_circle_rounded
                                  : Icons.workspaces_outline,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(workspace.name)),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false);
              },
              icon: const Icon(Icons.workspaces_outline),
            ),
          if (!isPhone)
            IconButton(
              tooltip: l10n.newWorkspaceTitle,
              onPressed: _promptCreateWorkspace,
              icon: const Icon(Icons.add_business_rounded),
            ),
          if (!isPhone)
            IconButton(
              tooltip: l10n.knowledgeTooltip,
              onPressed: shellAsync.valueOrNull?.workspaceId.isEmpty ?? true
                  ? null
                  : () => _openKnowledgeSheet(shellAsync.valueOrNull!),
              icon: const Icon(Icons.library_books_rounded),
            ),
          if (!isPhone)
            IconButton(
              tooltip: l10n.addMemberTooltip,
              onPressed:
                  (shellAsync.valueOrNull?.workspaceId.isEmpty ?? true) ||
                      !canManageMembers
                  ? null
                  : _promptAddMember,
              icon: const Icon(Icons.person_add_alt_1_rounded),
            ),
          if (isTablet)
            IconButton(
              tooltip: l10n.agents,
              onPressed: shellAsync.valueOrNull == null
                  ? null
                  : () {
                      final shell = shellAsync.valueOrNull!;
                      _openAgentSheet(
                        agents: shell.agents,
                        runs: shell.agentRuns,
                      );
                    },
              icon: const Icon(Icons.smart_toy_rounded),
            ),
          IconButton(
            tooltip: l10n.agentDiagnosticsTooltip,
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
          if (isDesktop || isTablet) ...[
            const ThemeModeSwitcher(),
            const SizedBox(width: 8),
            const LanguageSwitcher(),
            const SizedBox(width: 8),
          ],
          if (isDesktop || isTablet)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: appBarStatus),
            ),
          if (isPhone) ...[
            PopupMenuButton<_PhoneMenuAction>(
              tooltip: l10n.language,
              onSelected: (action) {
                _handlePhoneMenuSelection(
                  action,
                  shellAsync.valueOrNull,
                  canManageMembers,
                );
              },
              itemBuilder: (context) {
                final shell = shellAsync.valueOrNull;
                final hasWorkspace = shell?.workspaceId.isNotEmpty ?? false;
                return [
                  PopupMenuItem(
                    value: _PhoneMenuAction.newWorkspace,
                    child: Text(l10n.newWorkspaceTitle),
                  ),
                  if (hasWorkspace)
                    PopupMenuItem(
                      value: _PhoneMenuAction.knowledge,
                      child: Text(l10n.knowledgeTooltip),
                    ),
                  if (hasWorkspace && canManageMembers)
                    PopupMenuItem(
                      value: _PhoneMenuAction.addMember,
                      child: Text(l10n.addMemberTooltip),
                    ),
                  if (hasWorkspace)
                    PopupMenuItem(
                      value: _PhoneMenuAction.diagnostics,
                      child: Text(l10n.agentDiagnosticsTooltip),
                    ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: _PhoneMenuAction.lightMode,
                    child: Text(l10n.lightMode),
                  ),
                  PopupMenuItem(
                    value: _PhoneMenuAction.darkMode,
                    child: Text(l10n.darkMode),
                  ),
                  PopupMenuItem(
                    value: _PhoneMenuAction.chinese,
                    child: Text(l10n.simplifiedChinese),
                  ),
                  PopupMenuItem(
                    value: _PhoneMenuAction.english,
                    child: Text(l10n.english),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: _PhoneMenuAction.signOut,
                    child: Text(l10n.signOutTooltip),
                  ),
                ];
              },
              icon: const Icon(Icons.more_horiz_rounded),
            ),
            const SizedBox(width: 12),
          ] else ...[
            IconButton(
              tooltip: l10n.signOutTooltip,
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
            ),
            const SizedBox(width: 8),
          ],
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
                    Color(0xFFF8FAFA),
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
                  members: shell.workspaceMembers,
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
                final sidebarWidth = width >= 1440 ? 320.0 : 300.0;
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
                  knowledgeDocuments: shell.knowledgeDocuments,
                  onKnowledgeCitationTap: (documentId) {
                    _openKnowledgeSheet(shell, initialDocumentId: documentId);
                  },
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
                  collaborationSnapshot: shell.selectedCollaborationStatus,
                  collaborationRuns: shell.selectedCollaborationRuns,
                  onCollaborationModeChanged: (enabled) {
                    ref
                        .read(workspaceShellControllerProvider.notifier)
                        .setCollaborationModeForSelectedConversation(enabled);
                  },
                  compact: isCompactPhone,
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
                    compact: isPhone,
                    title: shell.workspaceName,
                    eyebrow: l10n.workspaceHub,
                    description: l10n.workspaceDescription,
                    primaryStatValue: '${conversations.length}',
                    primaryStatLabel: l10n.conversations,
                    secondaryStatValue: '$enabledAgents',
                    secondaryStatLabel: l10n.availableAgents,
                    note: l10n.privateConversationPreview,
                    primaryActionLabel: isPhone ? l10n.agents : null,
                    onPrimaryAction: isPhone
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
                  compact: isPhone,
                  title: l10n.noMessagesTitle,
                  eyebrow: shell.workspaceName,
                  description: l10n.noMessagesDescription,
                  primaryStatValue: '${conversations.length}',
                  primaryStatLabel: l10n.conversations,
                  secondaryStatValue: '$enabledAgents',
                  secondaryStatLabel: l10n.availableAgents,
                  note: l10n.agentConversationHint,
                  primaryActionLabel: isPhone ? l10n.collaboration : null,
                  onPrimaryAction: isPhone
                      ? () {
                          setState(() {
                            _mobileTabIndex = 1;
                          });
                        }
                      : null,
                  primaryActionIcon: Icons.grid_view_rounded,
                  secondaryActionLabel: isPhone ? l10n.agents : null,
                  onSecondaryAction: isPhone
                      ? () {
                          setState(() {
                            _mobileTabIndex = 2;
                          });
                        }
                      : null,
                  secondaryActionIcon: Icons.smart_toy_rounded,
                );

                return isDesktop
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
                                  width: sidebarWidth,
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
                    : isTablet
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
                                  width: sidebarWidth,
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
                                const SizedBox(width: 14),
                                Expanded(
                                  child: needsConversationSetup
                                      ? setupPanel
                                      : chatPanel,
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
                                          onConversationOpened: () {
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
      bottomNavigationBar: isPhone && !keyboardVisible
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
  VoidCallback? onConversationOpened,
}) async {
  await ref
      .read(workspaceShellControllerProvider.notifier)
      .selectConversation(
        conversationId: conversation.id,
        title: conversation.title,
        kind: _toSelectedConversationKind(conversation.kind),
        isAvailable: conversation.isAvailable,
      );
  onConversationOpened?.call();
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
  required List<WorkspaceMember> members,
}) {
  if (members.isEmpty) {
    return [
      WorkspaceMemberSummary(
        id: currentUserId,
        displayName: currentUserLabel,
        subtitle: l10n.online,
        accent: const Color(0xFF3D7EA6),
        isCurrentUser: true,
      ),
    ];
  }

  return members
      .map(
        (member) => WorkspaceMemberSummary(
          id: member.userId,
          displayName: member.displayName,
          subtitle: member.role == 'OWNER'
              ? l10n.ownerRole
              : member.email.isEmpty
              ? l10n.online
              : member.email,
          accent: member.userId == currentUserId
              ? const Color(0xFF3D7EA6)
              : member.role == 'OWNER'
              ? const Color(0xFF1F8A5C)
              : const Color(0xFF52796F),
          isCurrentUser: member.userId == currentUserId,
        ),
      )
      .toList(growable: false);
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

enum _PhoneMenuAction {
  newWorkspace,
  knowledge,
  addMember,
  diagnostics,
  lightMode,
  darkMode,
  chinese,
  english,
  signOut,
}

enum _KnowledgeUploadTarget { workspace, currentConversation }

enum _KnowledgeScopeFilter { all, currentConversation, workspaceOnly }

class _KnowledgeSheet extends StatefulWidget {
  const _KnowledgeSheet({
    required this.shell,
    this.initialDocumentId,
    required this.onRefresh,
    required this.onUpload,
  });

  final WorkspaceShellState shell;
  final String? initialDocumentId;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String? channelId) onUpload;

  @override
  State<_KnowledgeSheet> createState() => _KnowledgeSheetState();
}

class _KnowledgeSheetState extends State<_KnowledgeSheet> {
  String _query = '';
  late _KnowledgeUploadTarget _uploadTarget;
  _KnowledgeScopeFilter _scopeFilter = _KnowledgeScopeFilter.all;

  @override
  void initState() {
    super.initState();
    _uploadTarget = widget.shell.selectedChannelIdOrNull == null
        ? _KnowledgeUploadTarget.workspace
        : _KnowledgeUploadTarget.currentConversation;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final normalizedQuery = _query.trim().toLowerCase();
    final activeChannelId = widget.shell.selectedChannelIdOrNull;
    final hasChannelScopedTarget = activeChannelId != null;
    final currentConversationLabel = widget.shell.selectedConversation.title;
    KnowledgeDocument? highlightedDocument;
    final remainingDocuments = <KnowledgeDocument>[];

    for (final document in widget.shell.knowledgeDocuments) {
      final matchesScope = switch (_scopeFilter) {
        _KnowledgeScopeFilter.all => true,
        _KnowledgeScopeFilter.currentConversation =>
          activeChannelId != null && document.channelId == activeChannelId,
        _KnowledgeScopeFilter.workspaceOnly =>
          document.channelId == null || document.channelId!.isEmpty,
      };
      if (!matchesScope) {
        continue;
      }
      final matchesQuery =
          normalizedQuery.isEmpty ||
          document.fileName.toLowerCase().contains(normalizedQuery) ||
          document.summary.toLowerCase().contains(normalizedQuery) ||
          document.contentType.toLowerCase().contains(normalizedQuery);
      if (!matchesQuery) {
        continue;
      }
      if (document.id == widget.initialDocumentId) {
        highlightedDocument = document;
        continue;
      }
      remainingDocuments.add(document);
    }

    final filteredDocuments = <KnowledgeDocument>[...remainingDocuments];
    if (highlightedDocument != null) {
      filteredDocuments.insert(0, highlightedDocument);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.knowledgeBaseTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.shell.workspaceName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.64,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.refreshTooltip,
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: l10n.uploadFileTooltip,
                onPressed: widget.shell.isUploadingKnowledgeDocument
                    ? null
                    : () => widget.onUpload(
                        _uploadTarget ==
                                _KnowledgeUploadTarget.currentConversation
                            ? activeChannelId
                            : null,
                      ),
                icon: widget.shell.isUploadingKnowledgeDocument
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_rounded),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.dividerColor),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.uploadTargetLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.workspaceLibrary),
                      selected:
                          _uploadTarget == _KnowledgeUploadTarget.workspace,
                      onSelected: (_) {
                        setState(
                          () =>
                              _uploadTarget = _KnowledgeUploadTarget.workspace,
                        );
                      },
                    ),
                    if (hasChannelScopedTarget)
                      ChoiceChip(
                        label: Text(currentConversationLabel),
                        selected:
                            _uploadTarget ==
                            _KnowledgeUploadTarget.currentConversation,
                        onSelected: (_) {
                          setState(
                            () => _uploadTarget =
                                _KnowledgeUploadTarget.currentConversation,
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _uploadTarget == _KnowledgeUploadTarget.currentConversation &&
                          hasChannelScopedTarget
                      ? l10n.uploadTargetConversationDescription(
                          currentConversationLabel,
                        )
                      : l10n.uploadTargetWorkspaceDescription,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l10n.allDocuments),
                    selected: _scopeFilter == _KnowledgeScopeFilter.all,
                    onSelected: (_) {
                      setState(() => _scopeFilter = _KnowledgeScopeFilter.all);
                    },
                  ),
                  if (hasChannelScopedTarget)
                    ChoiceChip(
                      label: Text(currentConversationLabel),
                      selected:
                          _scopeFilter ==
                          _KnowledgeScopeFilter.currentConversation,
                      onSelected: (_) {
                        setState(
                          () => _scopeFilter =
                              _KnowledgeScopeFilter.currentConversation,
                        );
                      },
                    ),
                  ChoiceChip(
                    label: Text(l10n.workspaceWide),
                    selected:
                        _scopeFilter == _KnowledgeScopeFilter.workspaceOnly,
                    onSelected: (_) {
                      setState(
                        () =>
                            _scopeFilter = _KnowledgeScopeFilter.workspaceOnly,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: l10n.searchDocumentsHint,
                ),
              ),
            ],
          ),
        ),
        if (widget.shell.knowledgeError != null &&
            widget.shell.knowledgeError!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8E7E5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(widget.shell.knowledgeError!),
            ),
          ),
        if (highlightedDocument != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.16 : 0.08,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.referencedSourceNotice,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: filteredDocuments.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      widget.shell.knowledgeDocuments.isEmpty
                          ? l10n.knowledgeEmptyDescription
                          : l10n.knowledgeEmptySearchDescription,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.68,
                        ),
                        height: 1.5,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocuments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final document = filteredDocuments[index];
                    return _KnowledgeDocumentTile(
                      document: document,
                      scopeLabel: _knowledgeScopeLabel(
                        widget.shell,
                        document,
                        l10n,
                      ),
                      highlighted: document.id == widget.initialDocumentId,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _KnowledgeDocumentTile extends StatelessWidget {
  const _KnowledgeDocumentTile({
    required this.document,
    required this.scopeLabel,
    this.highlighted = false,
  });

  final KnowledgeDocument document;
  final String scopeLabel;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final createdAt = DateTime.tryParse(document.createdAt)?.toLocal();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted
            ? theme.colorScheme.primary.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.14 : 0.08,
              )
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted
              ? theme.colorScheme.primary.withValues(alpha: 0.28)
              : theme.dividerColor,
          width: highlighted ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  document.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                l10n.snippetsCount(document.snippetCount),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF3D7EA6),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (highlighted) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.bookmark_added_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.referencedSource,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            document.summary.isEmpty ? document.contentType : document.summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppPill(
                label: scopeLabel,
                icon: document.channelId == null || document.channelId!.isEmpty
                    ? Icons.public_rounded
                    : Icons.forum_rounded,
              ),
              AppPill(label: _formatBytes(document.sizeBytes)),
              Text(
                document.status,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (createdAt != null)
                Text(
                  '${createdAt.year}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
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
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$selectedConversationLabel · $statusLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _knowledgeScopeLabel(
  WorkspaceShellState shell,
  KnowledgeDocument document,
  AppLocalizations l10n,
) {
  final channelId = document.channelId;
  if (channelId == null || channelId.isEmpty) {
    return l10n.workspaceScopeLabel;
  }
  for (final conversation in shell.conversations) {
    if (conversation.id == channelId) {
      return conversation.title;
    }
  }
  for (final channel in shell.channels) {
    if (channel.id == channelId) {
      return channel.name;
    }
  }
  return l10n.scopedScopeLabel;
}
