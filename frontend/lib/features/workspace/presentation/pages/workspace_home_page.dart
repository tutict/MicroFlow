import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../app/router.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../../../core/providers/locale_controller.dart';
import '../../../../core/providers/theme_mode_controller.dart';
import '../../../../shared/layout/window_class.dart';
import '../../../../shared/theme/app_theme_extensions.dart';
import '../../../../shared/theme/app_tokens.dart';
import '../../../accounting/presentation/pages/accounting_page.dart';
import '../../../agents/presentation/pages/agent_diagnostics_page.dart';
import '../shell/shell_destination.dart';
import '../shell/workspace_destination_rail.dart';
import '../shell/workspace_inspector.dart';
import '../shell/workspace_shell_body.dart';
import '../shell/workspace_tools_list.dart';
import '../../../../shared/widgets/app_layout.dart';
import '../../../../shared/widgets/app_skeletons.dart';
import '../../../agents/domain/entities/agent_descriptor.dart';
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
  const WorkspaceHomePage({
    super.key,
    this.initialDestination = ShellDestination.conversation,
    this.initialWorkspaceId,
  });

  final ShellDestination initialDestination;
  final String? initialWorkspaceId;

  @override
  ConsumerState<WorkspaceHomePage> createState() => _WorkspaceHomePageState();
}

class _WorkspaceHomePageState extends ConsumerState<WorkspaceHomePage> {
  final GlobalKey<ScaffoldState> _drawerKey = GlobalKey<ScaffoldState>();
  late ShellDestination _destination;
  int _compactPane = 0;
  String? _knowledgeDocumentId;

  @override
  void initState() {
    super.initState();
    _destination = widget.initialDestination;
    final workspaceId = widget.initialWorkspaceId;
    if (workspaceId != null && workspaceId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref
            .read(workspaceShellControllerProvider.notifier)
            .selectWorkspace(workspaceId);
      });
    }
  }

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.signOutConfirmTitle),
          content: Text(l10n.signOutConfirmBody),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.signOutTooltip),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _completeSignOut();
  }

  Future<void> _completeSignOut() async {
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

  void _selectDestination(ShellDestination destination) {
    setState(() {
      _destination = destination;
      _compactPane = 0;
    });
  }

  WorkspaceToolsList _toolsFor(
    WorkspaceShellState shell, {
    VoidCallback? close,
  }) {
    void go(ShellDestination destination) {
      close?.call();
      _selectDestination(destination);
    }

    return WorkspaceToolsList(
      hasWorkspace: shell.workspaceId.isNotEmpty,
      onKnowledge: () => go(ShellDestination.knowledge),
      onAccounting: () => go(ShellDestination.accounting),
      onDiagnostics: () => go(ShellDestination.diagnostics),
      onUseLight: () {
        close?.call();
        ref
            .read(themeModeControllerProvider.notifier)
            .setThemeMode(ThemeMode.light);
      },
      onUseDark: () {
        close?.call();
        ref
            .read(themeModeControllerProvider.notifier)
            .setThemeMode(ThemeMode.dark);
      },
      onUseChinese: () {
        close?.call();
        ref
            .read(localeControllerProvider.notifier)
            .setLocale(const Locale('zh'));
      },
      onUseEnglish: () {
        close?.call();
        ref
            .read(localeControllerProvider.notifier)
            .setLocale(const Locale('en'));
      },
      onSignOut: () {
        close?.call();
        _signOut();
      },
      themeMode: ref.read(themeModeControllerProvider).value ?? ThemeMode.light,
      locale: ref.read(localeControllerProvider).value ?? const Locale('zh'),
    );
  }

  Future<void> _openTools(WorkspaceShellState shell) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SizedBox(
          height: 520,
          child: _toolsFor(
            shell,
            close: () => Navigator.of(sheetContext).pop(),
          ),
        );
      },
    );
  }

  Future<void> _uploadKnowledge({required String? targetChannelId}) async {
    final result = await FilePicker.pickFiles(withData: true);
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
              targetChannelId != null && targetChannelId.isNotEmpty,
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
                ref.watch(workspaceShellControllerProvider).value ?? shell;
            final theme = Theme.of(sheetContext);
            return FractionallySizedBox(
              heightFactor: 0.92,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadii.medium),
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
                    final result = await FilePicker.pickFiles(withData: true);
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
      case _PhoneMenuAction.accounting:
        if (!mounted || shell == null || shell.workspaceId.isEmpty) {
          return;
        }
        Navigator.of(
          context,
        ).pushNamed(AppRoutes.accounting, arguments: shell.workspaceId);
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final windowClass = AppWindowClassResolver.resolve(
      width: width,
      textScale: textScale,
    );
    final relaxedTitles = AppWindowClassResolver.relaxesLayout(textScale);
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isDesktop =
        windowClass == AppWindowClass.expanded ||
        windowClass == AppWindowClass.large;
    final isTablet = windowClass == AppWindowClass.medium;
    final isPhone = windowClass == AppWindowClass.compact;
    final isCompactPhone = width < 400;
    final workspaceName = shellAsync.value?.workspaceName;
    final workspaceLabel = workspaceName == null || workspaceName.isEmpty
        ? l10n.workspaceHub
        : workspaceName;
    final bodyPadding = EdgeInsets.all(isPhone ? AppSpacing.xs : AppSpacing.sm);
    final semantic = AppSemanticColors.of(context);
    final canManageMembers =
        shellAsync.value?.workspaceMembers.any(
          (member) =>
              member.userId == shellAsync.value?.currentUserId &&
              member.role == 'OWNER',
        ) ??
        false;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        titleSpacing: AppSpacing.md,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
              alignment: Alignment.center,
              child: Text(
                'MF',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ).copyWith(color: theme.colorScheme.onPrimary),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCompactPhone)
                    Text(
                      l10n.appTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  Text(
                    workspaceLabel,
                    maxLines: isCompactPhone ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (isCompactPhone
                                ? theme.textTheme.titleMedium
                                : theme.textTheme.bodySmall)
                            ?.copyWith(
                              color: isCompactPhone
                                  ? null
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (width >= 400 && (shellAsync.value?.workspaces.length ?? 0) > 1)
            PopupMenuButton<String>(
              tooltip: l10n.switchWorkspaceTooltip,
              onSelected: (workspaceId) {
                ref
                    .read(workspaceShellControllerProvider.notifier)
                    .selectWorkspace(workspaceId);
              },
              itemBuilder: (context) {
                final shell = shellAsync.value!;
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
          if (width >= 400)
            IconButton(
              tooltip: l10n.newWorkspaceTitle,
              onPressed: _promptCreateWorkspace,
              icon: const Icon(Icons.add_business_rounded),
            ),
          if (!isPhone)
            IconButton(
              tooltip: l10n.openToolsTooltip,
              onPressed: shellAsync.value == null
                  ? null
                  : () => _openTools(shellAsync.value!),
              icon: const Icon(Icons.handyman_outlined),
            ),
          if (isTablet || windowClass == AppWindowClass.expanded)
            IconButton(
              tooltip: l10n.openInspectorTooltip,
              onPressed: () => _drawerKey.currentState?.openEndDrawer(),
              icon: const Icon(Icons.view_sidebar_outlined),
            ),
          PopupMenuButton<_OverflowSelection>(
            tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
            onSelected: (selection) {
              final workspaceId = selection.workspaceId;
              if (workspaceId != null) {
                ref
                    .read(workspaceShellControllerProvider.notifier)
                    .selectWorkspace(workspaceId);
                return;
              }
              final action = selection.action;
              if (action == null) {
                return;
              }
              _handlePhoneMenuSelection(
                action,
                shellAsync.value,
                canManageMembers,
              );
            },
            itemBuilder: (context) {
              final shell = shellAsync.value;
              final hasWorkspace = shell?.workspaceId.isNotEmpty ?? false;
              final switchWorkspaces =
                  width < 400 && (shell?.workspaces.length ?? 0) > 1;
              return [
                if (switchWorkspaces)
                  for (final workspace in shell!.workspaces)
                    PopupMenuItem(
                      value: _OverflowSelection.workspace(workspace.id),
                      child: Row(
                        children: [
                          Icon(
                            workspace.id == shell.workspaceId
                                ? Icons.check_circle_rounded
                                : Icons.workspaces_outline,
                            size: 18,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(child: Text(workspace.name)),
                        ],
                      ),
                    ),
                if (width < 400)
                  PopupMenuItem(
                    value: const _OverflowSelection.action(
                      _PhoneMenuAction.newWorkspace,
                    ),
                    child: Text(l10n.newWorkspaceTitle),
                  ),
                if (hasWorkspace && canManageMembers)
                  PopupMenuItem(
                    value: const _OverflowSelection.action(
                      _PhoneMenuAction.addMember,
                    ),
                    child: Text(l10n.addMemberTooltip),
                  ),
                PopupMenuItem(
                  value: const _OverflowSelection.action(
                    _PhoneMenuAction.signOut,
                  ),
                  child: Text(l10n.signOutTooltip),
                ),
              ];
            },
            icon: const Icon(Icons.more_horiz_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: bodyPadding,
            child: shellAsync.when(
              data: (shell) {
                final conversations = _mapConversationSummaries(
                  shell.conversations,
                  colors: semantic,
                );
                final members = _buildWorkspaceMembers(
                  l10n: l10n,
                  currentUserId: shell.currentUserId,
                  currentUserLabel: shell.currentUserLabel,
                  members: shell.workspaceMembers,
                  colors: semantic,
                );
                final recentInteractions = _buildRecentInteractions(
                  l10n: l10n,
                  currentUserId: shell.currentUserId,
                  currentUserLabel: shell.currentUserLabel,
                  messages: shell.messages,
                  colors: semantic,
                );
                final enabledAgents = shell.agents
                    .where((agent) => agent.enabled)
                    .length;
                final isWorkspaceBootstrap =
                    shell.workspaceId.isEmpty && conversations.isEmpty;
                final needsConversationSetup =
                    !isWorkspaceBootstrap && conversations.isEmpty;
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
                  statusLabel: _connectionLabel(l10n, shell.connectionStatus),
                  statusColor: _connectionColor(
                    semantic,
                    shell.connectionStatus,
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
                    setState(() {
                      _knowledgeDocumentId = documentId;
                      _destination = ShellDestination.knowledge;
                      _compactPane = 0;
                    });
                  },
                  participants: _buildConversationParticipants(
                    l10n: l10n,
                    currentUserId: shell.currentUserId,
                    currentUserLabel: shell.currentUserLabel,
                    selectedConversation: shell.selectedConversation,
                    messages: shell.messages,
                    colors: semantic,
                  ),
                  activeParticipantCount: _conversationParticipantCount(
                    l10n: l10n,
                    currentUserId: shell.currentUserId,
                    currentUserLabel: shell.currentUserLabel,
                    selectedConversation: shell.selectedConversation,
                    messages: shell.messages,
                    colors: semantic,
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
                  compact: isPhone,
                  isSendingMessage: shell.isSendingMessage,
                  messageError: shell.messageError,
                  onSend: (value) {
                    return ref
                        .read(workspaceShellControllerProvider.notifier)
                        .sendMessage(value);
                  },
                );

                void openConversation(
                  WorkspaceConversationSummary conversation,
                ) {
                  _openConversation(
                    ref: ref,
                    conversation: conversation,
                    onConversationOpened: () {
                      setState(() {
                        _compactPane = 0;
                        _destination = ShellDestination.conversation;
                      });
                    },
                  );
                }

                final indexPanel = _ScrollablePanel(
                  child: WorkspacePanel(
                    workspaceName: shell.workspaceName,
                    description: l10n.workspaceDescription,
                    channels: _filterConversationSummaries(
                      shell.conversations,
                      WorkspaceConversationKind.channel,
                      colors: semantic,
                    ),
                    conversations: conversations,
                    members: members,
                    recentInteractions: recentInteractions,
                    selectedConversationId: shell.selectedConversationId,
                    compact: isPhone,
                    titleMaxLines: relaxedTitles ? 2 : 1,
                    onOpenConversation: openConversation,
                  ),
                );
                final setupPanel = _WorkspaceSetupPanel(
                  compact: isPhone,
                  title: isWorkspaceBootstrap
                      ? shell.workspaceName
                      : l10n.noMessagesTitle,
                  eyebrow: isWorkspaceBootstrap
                      ? l10n.workspaceHub
                      : shell.workspaceName,
                  description: isWorkspaceBootstrap
                      ? l10n.workspaceDescription
                      : l10n.noMessagesDescription,
                  primaryStatValue: '${conversations.length}',
                  primaryStatLabel: l10n.conversations,
                  secondaryStatValue: '$enabledAgents',
                  secondaryStatLabel: l10n.availableAgents,
                  primaryActionLabel: !isWorkspaceBootstrap && isPhone
                      ? l10n.indexTab
                      : null,
                  onPrimaryAction: !isWorkspaceBootstrap && isPhone
                      ? () => setState(() => _compactPane = 1)
                      : null,
                  primaryActionIcon: Icons.list_alt_rounded,
                  secondaryActionLabel: isWorkspaceBootstrap
                      ? l10n.signOutTooltip
                      : null,
                  onSecondaryAction: isWorkspaceBootstrap ? _signOut : null,
                  secondaryActionIcon: Icons.logout_rounded,
                );
                final conversationCanvas =
                    needsConversationSetup || isWorkspaceBootstrap
                    ? setupPanel
                    : chatPanel;
                final embeddedCanvas = switch (_destination) {
                  ShellDestination.knowledge => _EmbeddedDestination(
                    title: l10n.destinationKnowledge,
                    onBack: () =>
                        _selectDestination(ShellDestination.conversation),
                    child: _KnowledgeSheet(
                      shell: shell,
                      embedded: true,
                      initialDocumentId: _knowledgeDocumentId,
                      onRefresh: () {
                        return ref
                            .read(workspaceShellControllerProvider.notifier)
                            .refreshKnowledgeDocuments();
                      },
                      onUpload: (targetChannelId) =>
                          _uploadKnowledge(targetChannelId: targetChannelId),
                    ),
                  ),
                  ShellDestination.accounting => _EmbeddedDestination(
                    title: l10n.destinationAccounting,
                    onBack: () =>
                        _selectDestination(ShellDestination.conversation),
                    child: AccountingPage(
                      workspaceId: shell.workspaceId,
                      embedded: true,
                    ),
                  ),
                  ShellDestination.diagnostics => _EmbeddedDestination(
                    title: l10n.destinationDiagnostics,
                    onBack: () =>
                        _selectDestination(ShellDestination.conversation),
                    child: AgentDiagnosticsPage(
                      workspaceId: shell.workspaceId,
                      embedded: true,
                    ),
                  ),
                  ShellDestination.conversation => conversationCanvas,
                };
                final tools = _toolsFor(shell);
                final inspector = WorkspaceInspector(
                  title: shell.selectedConversation.title,
                  description: _conversationDescription(
                    l10n,
                    shell.selectedConversation,
                  ),
                  participants:
                      _buildConversationParticipants(
                            l10n: l10n,
                            currentUserId: shell.currentUserId,
                            currentUserLabel: shell.currentUserLabel,
                            selectedConversation: shell.selectedConversation,
                            messages: shell.messages,
                            colors: semantic,
                          )
                          .map(
                            (person) => InspectorPerson(
                              label: person.label,
                              icon: person.label.startsWith('@')
                                  ? Icons.smart_toy_outlined
                                  : Icons.person_outline_rounded,
                            ),
                          )
                          .toList(growable: false),
                  collaborationSummary:
                      _collaborationStatusText(
                        l10n,
                        shell.selectedCollaborationStatus,
                      ) ??
                      l10n.idle,
                  onOpenKnowledge: () =>
                      _selectDestination(ShellDestination.knowledge),
                );
                final showRail =
                    windowClass == AppWindowClass.expanded ||
                    windowClass == AppWindowClass.large;
                final showInspector =
                    windowClass == AppWindowClass.large &&
                    _destination == ShellDestination.conversation &&
                    !isWorkspaceBootstrap;
                final compactBody = switch (_compactPane) {
                  1 => indexPanel,
                  2 => tools,
                  _ => embeddedCanvas,
                };
                return FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: Scaffold(
                    key: _drawerKey,
                    backgroundColor: Colors.transparent,
                    endDrawer:
                        isTablet || windowClass == AppWindowClass.expanded
                        ? Drawer(width: 320, child: inspector)
                        : null,
                    body: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showRail)
                          WorkspaceDestinationRail(
                            selected: _destination,
                            showLabels: windowClass == AppWindowClass.large,
                            onSelected: _selectDestination,
                          ),
                        if (showRail) const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: WorkspaceShellBody(
                            windowClass: windowClass,
                            showIndex: !isWorkspaceBootstrap && !isPhone,
                            showInspector: showInspector,
                            index: indexPanel,
                            canvas: isPhone ? compactBody : embeddedCanvas,
                            inspector: inspector,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => WorkspaceHomeSkeleton(
                compact: isPhone,
                showAgents: isDesktop,
              ),
              error: (error, _) => Center(
                child: Text(l10n.workspaceLoadError(error.toString())),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: isPhone && !keyboardVisible
          ? _MobileBottomNav(
              currentIndex: _compactPane,
              onSelected: (index) {
                setState(() {
                  _compactPane = index;
                  if (index == 0) {
                    _destination = ShellDestination.conversation;
                  }
                });
              },
              items: [
                _MobileNavItemData(
                  icon: Icons.forum_outlined,
                  label: l10n.destinationConversation,
                ),
                _MobileNavItemData(
                  icon: Icons.list_alt_rounded,
                  label: l10n.indexTab,
                ),
                _MobileNavItemData(
                  icon: Icons.handyman_outlined,
                  label: l10n.toolsTab,
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
  List<WorkspaceConversation> conversations, {
  required AppSemanticColors colors,
}) {
  return conversations
      .map(
        (conversation) => WorkspaceConversationSummary(
          id: conversation.id,
          title: conversation.title,
          subtitle: conversation.subtitle,
          kind: _mapConversationKind(conversation.kind),
          accent: _accentForConversation(
            colors: colors,
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
  WorkspaceConversationKind kind, {
  required AppSemanticColors colors,
}) {
  return _mapConversationSummaries(
    conversations,
    colors: colors,
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
  required AppSemanticColors colors,
  required WorkspaceConversationKind kind,
  required bool available,
}) {
  return switch (kind) {
    WorkspaceConversationKind.channel => colors.channel,
    WorkspaceConversationKind.directMessage => colors.directMessage,
    WorkspaceConversationKind.agentThread =>
      available ? colors.agentThread : colors.neutral,
  };
}

List<WorkspaceMemberSummary> _buildWorkspaceMembers({
  required AppLocalizations l10n,
  required String currentUserId,
  required String currentUserLabel,
  required List<WorkspaceMember> members,
  required AppSemanticColors colors,
}) {
  if (members.isEmpty) {
    return [
      WorkspaceMemberSummary(
        id: currentUserId,
        displayName: currentUserLabel,
        subtitle: l10n.online,
        accent: colors.channel,
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
              ? colors.channel
              : member.role == 'OWNER'
              ? colors.agentThread
              : colors.directMessage,
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
  required AppSemanticColors colors,
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
          accent: message.isAgent ? colors.agentThread : colors.directMessage,
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
  required AppSemanticColors colors,
}) {
  if (selectedConversation.kind ==
      WorkspaceSelectedConversationKind.directMessage) {
    return [
      ChatParticipantPreview(label: currentUserLabel, accent: colors.channel),
      ChatParticipantPreview(
        label: selectedConversation.title,
        accent: colors.directMessage,
      ),
    ];
  }

  if (selectedConversation.kind ==
      WorkspaceSelectedConversationKind.agentThread) {
    return [
      ChatParticipantPreview(label: currentUserLabel, accent: colors.channel),
      ChatParticipantPreview(
        label: selectedConversation.title,
        accent: colors.agentThread,
      ),
    ];
  }

  final participants = <ChatParticipantPreview>[
    ChatParticipantPreview(label: currentUserLabel, accent: colors.channel),
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
          accent: colors.agentThread,
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
        accent: colors.directMessage,
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
  required AppSemanticColors colors,
}) {
  return _buildConversationParticipants(
    l10n: l10n,
    currentUserId: currentUserId,
    currentUserLabel: currentUserLabel,
    selectedConversation: selectedConversation,
    messages: messages,
    colors: colors,
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

final class _OverflowSelection {
  const _OverflowSelection.action(this.action) : workspaceId = null;

  const _OverflowSelection.workspace(this.workspaceId) : action = null;

  final _PhoneMenuAction? action;
  final String? workspaceId;
}

enum _PhoneMenuAction {
  newWorkspace,
  knowledge,
  accounting,
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

class _EmbeddedDestination extends StatelessWidget {
  const _EmbeddedDestination({
    required this.title,
    required this.onBack,
    required this.child,
  });

  final String title;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppToolbar(
          title: title,
          leading: IconButton(
            tooltip: l10n.backToConversation,
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _KnowledgeSheet extends StatefulWidget {
  const _KnowledgeSheet({
    required this.shell,
    this.initialDocumentId,
    this.embedded = false,
    required this.onRefresh,
    required this.onUpload,
  });

  final WorkspaceShellState shell;
  final String? initialDocumentId;
  final bool embedded;
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              if (!widget.embedded)
                Expanded(
                  child: Text(
                    l10n.knowledgeBaseTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                )
              else
                const Spacer(),
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
              if (!widget.embedded)
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadii.medium),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.uploadTargetLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<_KnowledgeUploadTarget>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: _KnowledgeUploadTarget.workspace,
                        icon: const Icon(Icons.hub_outlined),
                        label: Text(l10n.workspaceLibrary),
                      ),
                      if (hasChannelScopedTarget)
                        ButtonSegment(
                          value: _KnowledgeUploadTarget.currentConversation,
                          icon: const Icon(Icons.forum_outlined),
                          label: Text(currentConversationLabel),
                        ),
                    ],
                    selected: {_uploadTarget},
                    onSelectionChanged: (selection) {
                      setState(() => _uploadTarget = selection.first);
                    },
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
                color: AppSemanticColors.of(context).dangerContainer,
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              child: Text(
                widget.shell.knowledgeError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppSemanticColors.of(context).danger,
                ),
              ),
            ),
          ),
        if (highlightedDocument != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppSemanticColors.of(context).infoContainer,
                borderRadius: BorderRadius.circular(AppRadii.medium),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 18,
                    color: AppSemanticColors.of(context).info,
                  ),
                  const SizedBox(width: AppSpacing.xs),
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
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocuments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
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

    final semantic = AppSemanticColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: highlighted
            ? semantic.selectedOverlay
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border(
          left: BorderSide(
            color: highlighted ? theme.colorScheme.primary : theme.dividerColor,
            width: highlighted ? 2 : 1,
          ),
          top: BorderSide(color: theme.dividerColor),
          right: BorderSide(color: theme.dividerColor),
          bottom: BorderSide(color: theme.dividerColor),
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                l10n.snippetsCount(document.snippetCount),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppSemanticColors.of(context).channel,
                  fontWeight: FontWeight.w600,
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
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l10n.referencedSource,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            document.summary.isEmpty ? document.contentType : document.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                document.channelId == null || document.channelId!.isEmpty
                    ? Icons.public_rounded
                    : Icons.forum_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              Text(scopeLabel, style: theme.textTheme.labelSmall),
              Text(_formatBytes(document.sizeBytes)),
              Text(
                document.status,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (createdAt != null)
                Text(
                  '${createdAt.year}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _DesktopMetricPill extends StatelessWidget {
  const _DesktopMetricPill({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 112,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final IconData primaryActionIcon;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final IconData secondaryActionIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPane(
      padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
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
            if (primaryActionLabel != null || secondaryActionLabel != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
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
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
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
        borderRadius: BorderRadius.circular(AppRadii.small),
        onTap: onTap,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppMotion.fast,
          curve: AppMotion.curve,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppSemanticColors.of(context).selectedOverlay
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.small),
            border: Border(
              top: BorderSide(
                color: selected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                data.icon,
                size: 20,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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

Color _connectionColor(AppSemanticColors colors, ChatConnectionStatus? status) {
  return switch (status) {
    ChatConnectionStatus.connected => colors.success,
    ChatConnectionStatus.connecting => colors.info,
    ChatConnectionStatus.error => colors.danger,
    _ => colors.neutral,
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
