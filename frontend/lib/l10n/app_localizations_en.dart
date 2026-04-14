// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MicroFlow';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get lightMode => 'Light';

  @override
  String get darkMode => 'Dark';

  @override
  String get english => 'English';

  @override
  String get simplifiedChinese => 'Simplified Chinese';

  @override
  String get searchContacts => 'Search contacts';

  @override
  String get signInTitle => 'Sign in to MicroFlow';

  @override
  String get signInDescription => 'Connect the local workspace, authenticate, then start real-time collaboration.';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signingIn => 'Signing in...';

  @override
  String get enterWorkspace => 'Enter workspace';

  @override
  String restoreSessionError(Object error) {
    return 'Unable to restore session: $error';
  }

  @override
  String workspaceLoadError(Object error) {
    return 'Unable to load workspace: $error';
  }

  @override
  String get signOutTooltip => 'Sign out';

  @override
  String get workspaceDescription => 'Focused collaboration workspace for local AI execution, encrypted storage, and lightweight delivery.';

  @override
  String get workspace => 'Workspace';

  @override
  String get workspaceHub => 'Workspace hub';

  @override
  String get collaboration => 'Collaboration';

  @override
  String get conversations => 'Conversations';

  @override
  String get channels => 'Channels';

  @override
  String get members => 'Members';

  @override
  String get chatTab => 'Chat';

  @override
  String get pinnedChannels => 'Pinned channels';

  @override
  String get automationChannels => 'Automation';

  @override
  String get teamChannels => 'Team channels';

  @override
  String get contacts => 'Contacts';

  @override
  String get membersGroup => 'Members';

  @override
  String get agentsGroup => 'Agents';

  @override
  String contactsCount(int count) {
    return '$count contacts';
  }

  @override
  String channelTotal(int count) {
    return '$count total';
  }

  @override
  String conversationCountLabel(int count) {
    return '$count conversations';
  }

  @override
  String get unreadLabel => 'Unread';

  @override
  String get directMessages => 'Direct messages';

  @override
  String get agentThreads => 'Agent threads';

  @override
  String get previewLabel => 'Preview';

  @override
  String get memberConversationHint => '1:1 team conversation';

  @override
  String get agentConversationHint => 'Private thread with AI coworker';

  @override
  String get privateConversationPreview => 'Private conversation entry is ready in the UI. Backend conversation APIs are the next step.';

  @override
  String get localFirst => 'Local-first';

  @override
  String get sqlite => 'SQLite';

  @override
  String get virtualThreads => 'Virtual Threads';

  @override
  String get online => 'Online';

  @override
  String activeCountLabel(int count) {
    return '$count active';
  }

  @override
  String messageCountLabel(int count) {
    return '$count messages';
  }

  @override
  String get recentActivityLabel => 'Recent activity';

  @override
  String get recentInteractions => 'Recent interactions';

  @override
  String get noRecentInteractions => 'No recent interactions yet. Team messages and agent replies will appear here.';

  @override
  String get aiCoworker => 'AI coworker';

  @override
  String get connected => 'Connected';

  @override
  String get connecting => 'Connecting';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get realtimeError => 'Realtime error';

  @override
  String get idle => 'Idle';

  @override
  String get aiEnabled => 'AI enabled';

  @override
  String get chatPanelDescription => 'A shared team conversation with AI support available through @mention when needed.';

  @override
  String get noMessagesTitle => 'No messages yet';

  @override
  String get noMessagesDescription => 'Start the conversation with a team update, then mention an agent only when you need help.';

  @override
  String get quickActionsLabel => 'Quick actions';

  @override
  String get pressEnterToSend => 'Press Enter to send';

  @override
  String get sendingMessage => 'Sending message...';

  @override
  String get typeMessageHint => 'Type a message for the team, or use @assistant when needed';

  @override
  String membersCountLabel(int count) {
    return '$count members';
  }

  @override
  String get send => 'Send';

  @override
  String get sending => 'Sending';

  @override
  String messageSendFailed(Object error) {
    return 'Message send failed: $error';
  }

  @override
  String get agents => 'Agents';

  @override
  String get availableAgents => 'Available agents';

  @override
  String enabledCount(int count) {
    return '$count enabled';
  }

  @override
  String queueCountLabel(int count) {
    return '$count queued';
  }

  @override
  String get enabled => 'Enabled';

  @override
  String get disabled => 'Disabled';

  @override
  String get runActivity => 'Run Activity';

  @override
  String get noAgentExecutions => 'No agent executions yet. Mention an agent in chat to start a run.';

  @override
  String get queued => 'Queued';

  @override
  String get running => 'Running';

  @override
  String get completed => 'Completed';

  @override
  String get failed => 'Failed';

  @override
  String executionLabel(Object id) {
    return 'Execution $id';
  }

  @override
  String get aiBadge => 'AI';

  @override
  String memberLabel(Object id) {
    return 'Member $id';
  }

  @override
  String get memberYouLabel => 'You';

  @override
  String get todayLabel => 'Today';

  @override
  String get yesterdayLabel => 'Yesterday';

  @override
  String get agentRunsTitle => 'Agent Runs';

  @override
  String get recentExecutions => 'Recent executions';

  @override
  String get collaborationMode => 'Team mode';

  @override
  String get collaborationModeHint => 'Auto-route new channel messages through @team.';

  @override
  String collaborationRoundStatus(int round, int total) {
    return 'round $round of $total';
  }

  @override
  String collaborationRunningStatus(Object agentLabel, Object roundLabel) {
    return '$agentLabel is coordinating $roundLabel.';
  }

  @override
  String collaborationCompletedStatus(Object trigger, int totalRounds) {
    return 'Team run finished via $trigger in $totalRounds rounds.';
  }

  @override
  String get collaborationStoppedStatus => 'Team run stopped.';

  @override
  String get summarizeArchitectureChanges => 'Summarize architecture changes';

  @override
  String get nativeImagePreflightChecks => 'Native image preflight checks';

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get add => 'Add';

  @override
  String get newWorkspaceTitle => 'New workspace';

  @override
  String get workspaceNameLabel => 'Workspace name';

  @override
  String get workspaceNameHint => 'Platform Ops';

  @override
  String get addWorkspaceMemberTitle => 'Add workspace member';

  @override
  String get userEmailLabel => 'User email';

  @override
  String get userEmailHint => 'teammate@microflow.local';

  @override
  String get switchWorkspaceTooltip => 'Switch workspace';

  @override
  String get knowledgeTooltip => 'Knowledge';

  @override
  String get addMemberTooltip => 'Add member';

  @override
  String get agentDiagnosticsTooltip => 'Agent diagnostics';

  @override
  String get ownerRole => 'Owner';

  @override
  String get knowledgeBaseTitle => 'Knowledge base';

  @override
  String get refreshTooltip => 'Refresh';

  @override
  String get uploadFileTooltip => 'Upload file';

  @override
  String get uploadTargetLabel => 'Upload target';

  @override
  String get workspaceLibrary => 'Workspace library';

  @override
  String uploadTargetConversationDescription(Object conversation) {
    return 'New files will be attached to $conversation and prioritized there during retrieval.';
  }

  @override
  String get uploadTargetWorkspaceDescription => 'New files will be available as workspace-wide knowledge across conversations.';

  @override
  String get allDocuments => 'All documents';

  @override
  String get workspaceWide => 'Workspace-wide';

  @override
  String get searchDocumentsHint => 'Search documents';

  @override
  String get referencedSourceNotice => 'Referenced source highlighted from chat citation.';

  @override
  String get knowledgeEmptyDescription => 'Upload text, markdown, JSON or notes to ground agent replies with workspace knowledge.';

  @override
  String get knowledgeEmptySearchDescription => 'No knowledge documents match the current search.';

  @override
  String snippetsCount(int count) {
    return '$count snippets';
  }

  @override
  String get referencedSource => 'Referenced source';

  @override
  String get teamRunsAvailable => 'Persisted team runs are available for this conversation.';

  @override
  String get history => 'History';

  @override
  String get recentRuns => 'Recent runs';

  @override
  String get runHistory => 'Run history';

  @override
  String get noRunsMatchFilters => 'No runs match current filters.';

  @override
  String get filterRuns => 'Filter runs';

  @override
  String get allRuns => 'All runs';

  @override
  String get currentRun => 'Current run';

  @override
  String get filterByStatus => 'Filter by status';

  @override
  String get allStatuses => 'All statuses';

  @override
  String get stopped => 'Stopped';

  @override
  String get filterByAgent => 'Filter by agent';

  @override
  String get allAgents => 'All agents';

  @override
  String get live => 'Live';

  @override
  String eventsCount(int count) {
    return '$count events';
  }

  @override
  String roundsCount(int round, int total) {
    return '$round of $total rounds';
  }

  @override
  String reasonLabel(Object reason) {
    return 'Reason: $reason';
  }

  @override
  String get analyzeStage => 'Analyze';

  @override
  String get critiqueStage => 'Critique';

  @override
  String get synthesizeStage => 'Synthesize';

  @override
  String get deliverStage => 'Deliver';

  @override
  String collaborationStageInProgress(Object stage) {
    return '$stage in progress';
  }

  @override
  String collaborationStageCompleted(Object stage) {
    return '$stage completed';
  }

  @override
  String collaborationStageStopped(Object stage) {
    return '$stage stopped';
  }

  @override
  String collaborationStageFailed(Object stage) {
    return '$stage failed';
  }

  @override
  String collaborationStageStatus(Object stage, Object status) {
    return '$stage $status';
  }

  @override
  String get workspaceScopeLabel => 'Workspace';

  @override
  String get scopedScopeLabel => 'Scoped';
}
